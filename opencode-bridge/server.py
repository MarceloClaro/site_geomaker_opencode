import os
import sys
import json
import subprocess
import asyncio
import time
import uuid
import shutil
import zipfile
import io
import re
import unicodedata
from datetime import datetime
from pathlib import Path
from typing import AsyncGenerator, Optional
from fastapi import FastAPI, HTTPException, Query, Path as FPath
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, FileResponse
from pydantic import BaseModel

app = FastAPI(title="OpenCode Bridge — Geomaker")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

OPENCODE_BIN = os.environ.get("OPENCODE_BIN", "")
if not OPENCODE_BIN:
    candidates = [
        "/home/marceloclaro/.npm-global/bin/opencode",
        "/usr/local/bin/opencode",
        "/usr/bin/opencode",
    ]
    for c in candidates:
        if os.path.isfile(c):
            OPENCODE_BIN = c
            break

WORK_DIR = os.environ.get("OPENCODE_WORK_DIR", "/home/marceloclaro/opencode-ecosystem-core")

MODEL = os.environ.get("OPENCODE_MODEL", "opencode/deepseek-v4-flash-free")
PROJETOS_DIR = Path("/opt/geomaker/data/projetos")
TEMPLATE_TEX = Path(__file__).parent / "templates" / "relatorio.tex"
SITE_DIR = Path("/opt/geomaker/site")
PROJETOS_DIR.mkdir(parents=True, exist_ok=True)


class ChatRequest(BaseModel):
    prompt: str
    context: str = ""
    model: str = ""


class ChatResponse(BaseModel):
    text: str
    model: str
    tokens_input: int = 0
    tokens_output: int = 0
    cost: float = 0.0
    error: str = ""


AGENT = os.environ.get("OPENCODE_AGENT", "marceloclaro")

SYSTEM_CONTEXT = (
    "Você é o Geólogo Digital, um assistente especializado em geologia, "
    "paleontologia e museologia escolar do Museu Geomaker, operando pelo orquestrador /marceloclaro. "
    "Responda SEMPRE em formato de dissertação acadêmica em português brasileiro formal. "
    "ESTRUTURE a resposta com: introdução, desenvolvimento em seções numeradas, considerações finais. "
    "BASEIE suas respostas em conhecimento científico geológico e paleontológico. "
    "CITE obrigatoriamente referências reais com links e DOIs ativos e auditáveis no formato: "
    "Autor(es) (Ano). Título. Periódico/Editora. DOI: 10.xxxx/xxxxx. URL: https://doi.org/... "
    "APÓS as considerações finais, inclua as seções:\n"
    "## Referências\n(com DOI e links)\n\n"
    "## Apêndice: Fichamentos e Resenhas Críticas\n"
    "Para cada referência citada, forneça:\n"
    "### Fichamento N — Título da Obra\n"
    "- **Tipo:** artigo/livro/tese\n"
    "- **Autores:** ...\n"
    "- **Ano:** ...\n"
    "- **Palavras-chave:** ...\n"
    "- **Resumo:** (3-5 linhas)\n"
    "- **Citação-chave:** ...\n"
    "- **Link/DOI:** ...\n\n"
    "**Resenha Crítica:** (5-8 linhas analisando contribuição, limitações, "
    "relevância para o tema, posicionamento crítico)\n\n"
    "Se não souber, diga claramente que não pode responder com base apenas no contexto fornecido."
)


def _get_model(req_model: str = "") -> str:
    return req_model or MODEL


async def _run_opencode(prompt: str, model: str, agent: Optional[str] = None) -> tuple[str, str, int, int, float]:
    cmd = [OPENCODE_BIN, "run", "--format", "json", "--model", model, "--pure"]
    if agent:
        cmd += ["--agent", agent]
    proc = await asyncio.create_subprocess_exec(
        *cmd, prompt,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=WORK_DIR,
        env={**os.environ, "OPENCODE_CLI_NONINTERACTIVE": "1"},
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=300)
    except asyncio.TimeoutError:
        proc.kill()
        return "", "", 0, 0, 0.0

    if proc.returncode != 0:
        err_text = stderr.decode("utf-8", errors="replace")[:500]
        return "", err_text, 0, 0, 0.0

    texts: list[str] = []
    tokens_input = 0
    tokens_output = 0
    cost = 0.0

    for line in stdout.decode("utf-8", errors="replace").splitlines():
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        etype = event.get("type")
        part = event.get("part") or {}
        if etype == "text":
            t = part.get("text", "")
            if t:
                texts.append(t)
        if etype == "step_finish":
            tokens = part.get("tokens") or {}
            tokens_input = tokens.get("input", 0)
            tokens_output = tokens.get("output", 0)
            cost = tokens.get("cost", 0.0)

    result = "".join(texts).strip()
    return result, "", tokens_input, tokens_output, cost


async def _stream_opencode(prompt: str, model: str, agent: Optional[str] = None) -> AsyncGenerator[str, None]:
    cmd = [OPENCODE_BIN, "run", "--format", "json", "--model", model, "--pure"]
    if agent:
        cmd += ["--agent", agent]
    proc = await asyncio.create_subprocess_exec(
        *cmd, prompt,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=WORK_DIR,
        env={**os.environ, "OPENCODE_CLI_NONINTERACTIVE": "1"},
    )
    start_time = time.time()
    tokens_input = 0
    tokens_output = 0
    cost = 0.0
    error = ""

    # O orquestrador /marceloclaro pode ficar em silêncio por bastante tempo
    # antes do primeiro token (delegação a subagentes, pesquisa, etc.). Sem
    # bytes fluindo, túneis como o Cloudflare quick-tunnel cortam a conexão
    # com HTTP 524 (timeout de inatividade ~100s) mesmo que o servidor
    # continue processando normalmente. Por isso, os eventos do subprocesso
    # são coletados em uma fila por uma task em background, e o loop
    # principal envia um comentário SSE de keep-alive sempre que a fila
    # ficar mais que KEEPALIVE_INTERVAL segundos sem novidade.
    queue: "asyncio.Queue[object]" = asyncio.Queue()
    _DONE = object()
    KEEPALIVE_INTERVAL = 8.0

    async def read_stdout():
        nonlocal tokens_input, tokens_output, cost
        try:
            assert proc.stdout is not None
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                text = line.decode("utf-8", errors="replace").strip()
                if not text:
                    continue
                try:
                    event = json.loads(text)
                except json.JSONDecodeError:
                    continue
                etype = event.get("type")
                part = event.get("part") or {}
                if etype == "text":
                    t = part.get("text", "")
                    if t:
                        await queue.put(f"event: token\ndata: {json.dumps({'text': t}, ensure_ascii=False)}\n\n")
                if etype == "step_finish":
                    tokens = part.get("tokens") or {}
                    tokens_input = tokens.get("input", 0)
                    tokens_output = tokens.get("output", 0)
                    cost = tokens.get("cost", 0.0)
        finally:
            # Garante que o loop principal nunca fique esperando a fila para
            # sempre, mesmo se ocorrer uma exceção inesperada aqui.
            await queue.put(_DONE)

    async def read_stderr():
        nonlocal error
        assert proc.stderr is not None
        stderr = (await proc.stderr.read()).decode("utf-8", errors="replace")[:500]
        if stderr:
            error = stderr

    reader_task = asyncio.create_task(read_stdout())
    stderr_task = asyncio.create_task(read_stderr())

    # Limite rígido de tempo total: evita que o subprocesso `opencode run`
    # fique órfão consumindo CPU/memória indefinidamente caso o orquestrador
    # trave ou demore excessivamente (observado: /marceloclaro pode levar
    # vários minutos até o primeiro token).
    MAX_TOTAL_SECONDS = 240.0
    timed_out = False

    try:
        while True:
            if time.time() - start_time > MAX_TOTAL_SECONDS:
                timed_out = True
                break
            try:
                item = await asyncio.wait_for(queue.get(), timeout=KEEPALIVE_INTERVAL)
            except asyncio.TimeoutError:
                yield ": keep-alive\n\n"
                continue
            if item is _DONE:
                break
            yield item  # type: ignore[misc]
    finally:
        # Encerra o subprocesso agressivamente em QUALQUER caminho de saída
        # (conclusão normal, timeout, ou cancelamento por desconexão do
        # cliente) — sem isso, processos `opencode run` ficam órfãos.
        if proc.returncode is None:
            try:
                proc.kill()
            except ProcessLookupError:
                pass
        reader_task.cancel()
        stderr_task.cancel()
        await asyncio.gather(reader_task, stderr_task, proc.wait(), return_exceptions=True)

    elapsed = time.time() - start_time

    if timed_out:
        yield f"event: error\ndata: {json.dumps({'message': f'Tempo limite de {int(MAX_TOTAL_SECONDS)}s excedido sem resposta completa do orquestrador /marceloclaro.'}, ensure_ascii=False)}\n\n"
    elif proc.returncode != 0:
        yield f"event: error\ndata: {json.dumps({'message': f'Processo encerrado com código {proc.returncode}: {error}'}, ensure_ascii=False)}\n\n"
    else:
        yield f"event: done\ndata: {json.dumps({'tokens_input': tokens_input, 'tokens_output': tokens_output, 'cost': cost, 'elapsed': round(elapsed, 1)}, ensure_ascii=False)}\n\n"


@app.get("/health")
@app.get("/api/health")
def health():
    return {"status": "ok", "bin": OPENCODE_BIN, "model": MODEL, "agent": AGENT}


ERRO_TXT = SITE_DIR / "erros" / "erro.txt"


@app.get("/api/erro.txt")
def erro_txt():
    if not ERRO_TXT.exists():
        return {"error": "erro.txt não encontrado"}
    from fastapi.responses import FileResponse
    return FileResponse(str(ERRO_TXT), media_type="text/plain; charset=utf-8",
                        filename="erro.txt")


@app.post("/api/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    if not OPENCODE_BIN or not os.path.isfile(OPENCODE_BIN):
        raise HTTPException(status_code=503, detail="OpenCode CLI não encontrado")

    model = _get_model(req.model)
    context = SYSTEM_CONTEXT
    if req.context:
        context += f"\n\nContexto sobre a peça analisada:\n{req.context}"
    full_prompt = f"{context}\n\n---\n\n{req.prompt}"

    result, error, ti, to, c = await _run_opencode(full_prompt, model)
    if error:
        return ChatResponse(text="", error=error, model=model)
    if not result:
        return ChatResponse(text="", error="O modelo respondeu vazio ou não foi possível extrair o texto.", model=model)
    return ChatResponse(text=result, model=model, tokens_input=ti, tokens_output=to, cost=c)


@app.get("/api/terminal")
async def terminal_stream(
    prompt: str = Query(..., description="Pergunta para o Geólogo Digital"),
    model: str = Query("", description="Modelo OpenCode"),
):
    if not OPENCODE_BIN or not os.path.isfile(OPENCODE_BIN):
        raise HTTPException(status_code=503, detail="OpenCode CLI não encontrado")

    model = _get_model(model)
    full_prompt = f"{SYSTEM_CONTEXT}\n\n---\n\n{prompt}"

    return StreamingResponse(
        _stream_opencode(full_prompt, model),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@app.post("/api/terminal")
async def terminal_post(prompt: str = Query(...), model: str = Query("")):
    return await terminal_stream(prompt, model)


# ── Projetos — pasta por consulta com MD/tex/PDF ──────────────────────

def _sanitize_filename(text: str) -> str:
    return re.sub(r'[^\w\s-]', '', text).strip()[:60] or "consulta"


# ── Conversor Markdown → LaTeX (ABNT) ──────────────────────────────────
# Converte a dissertação em Markdown produzida pelo agente /marceloclaro
# para LaTeX com hierarquia de seções, listas, negrito/itálico e — crucial
# para auditabilidade — DOIs e URLs citados tornam-se hyperlinks reais
# (\href / \url), permitindo verificação direta de cada referência no PDF.

def _tex_escape(s: str) -> str:
    return (s.replace("\\", "\\textbackslash{}")
            .replace("&", "\\&")
            .replace("%", "\\%")
            .replace("#", "\\#")
            .replace("$", "\\$")
            .replace("_", "\\_")
            .replace("{", "\\{")
            .replace("}", "\\}")
            .replace("~", "\\textasciitilde{}")
            .replace("^", "\\textasciicircum{}"))


def _strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


_REF_TOKEN = re.compile(r"referenc|bibliograf", re.IGNORECASE)
_APP_TOKEN = re.compile(r"apendice|anexo", re.IGNORECASE)


def _inline_format(text: str) -> str:
    """Formata negrito/itálico/código e converte links, DOIs e URLs em
    hyperlinks LaTeX auditáveis, escapando o restante do texto."""
    placeholders: list[str] = []

    def stash(code: str) -> str:
        placeholders.append(code)
        return f"\x00{len(placeholders) - 1}\x00"

    # Links markdown [rótulo](url)
    text = re.sub(
        r"\[([^\]]+)\]\(([^)\s]+)\)",
        lambda m: stash(f"\\href{{{m.group(2)}}}{{{_tex_escape(m.group(1))}}}"),
        text,
    )
    # DOI (com ou sem URL doi.org) — o número em si se torna link clicável e
    # auditável; o texto ao redor ("DOI:", "Disponível em:", "**DOI:**" etc.)
    # é preservado como está, evitando qualquer duplicação de rótulo.
    text = re.sub(
        r"(?:https?://(?:dx\.)?doi\.org/)?\b(10\.\d{4,9}/[^\s,;\)\]]+)",
        lambda m: stash(f"\\href{{https://doi.org/{m.group(1)}}}{{{_tex_escape(m.group(1))}}}"),
        text,
    )
    # URLs soltas restantes
    text = re.sub(
        r"https?://[^\s\)\]]+",
        lambda m: stash(f"\\url{{{m.group(0).rstrip('.,;')}}}"),
        text,
    )
    # **negrito**
    text = re.sub(r"\*\*([^*]+)\*\*", lambda m: stash(f"\\textbf{{{_tex_escape(m.group(1))}}}"), text)
    # *itálico*
    text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", lambda m: stash(f"\\textit{{{_tex_escape(m.group(1))}}}"), text)
    # `código`
    text = re.sub(r"`([^`]+)`", lambda m: stash(f"\\texttt{{{_tex_escape(m.group(1))}}}"), text)

    text = _tex_escape(text)
    text = re.sub(r"\x00(\d+)\x00", lambda m: placeholders[int(m.group(1))], text)
    return text


def markdown_to_latex(text: str) -> str:
    """Converte a dissertação Markdown do agente em LaTeX com estrutura
    ABNT: seções numeradas para o corpo, e Referências/Apêndice tratados
    como elementos pós-textuais (não numerados, mas presentes no sumário).
    Listas de referência usam recuo ABNT (sem marcador), preservando os
    hyperlinks de DOI/URL para auditoria."""
    lines = text.replace("\r\n", "\n").split("\n")
    out: list[str] = []
    in_list = False
    in_numlist = False
    in_refs = False
    in_appendix = False

    def close_lists():
        nonlocal in_list, in_numlist
        if in_list:
            out.append("\\end{itemize}")
            in_list = False
        if in_numlist:
            out.append("\\end{enumerate}")
            in_numlist = False

    for raw in lines:
        line = raw.rstrip()
        stripped = line.strip()

        if not stripped:
            close_lists()
            out.append("")
            continue

        m = re.match(r"^(#{1,4})\s+(.*)$", stripped)
        if m:
            close_lists()
            level = len(m.group(1))
            title_raw = m.group(2).strip()
            content = _inline_format(title_raw)
            unnumbered = in_refs or in_appendix

            if level <= 2:
                # Cabeçalho de topo — reavalia se é Referências/Apêndice (elemento
                # pós-textual ABNT) ou uma nova seção numerada comum do corpo.
                is_ref = bool(_REF_TOKEN.search(_strip_accents(title_raw)))
                is_app = bool(_APP_TOKEN.search(_strip_accents(title_raw)))
                in_refs = is_ref
                in_appendix = is_app
                if is_ref or is_app:
                    out.append(f"\\section*{{{content}}}")
                    out.append(f"\\addcontentsline{{toc}}{{section}}{{{content}}}")
                else:
                    out.append(f"\\section{{{content}}}")
            elif level == 3:
                # Subseções dentro de Referências/Apêndice permanecem não numeradas
                # (evita "vazar" numeração da última seção numérica do corpo, ex.: 3.1).
                if unnumbered:
                    out.append(f"\\subsection*{{{content}}}")
                    out.append(f"\\addcontentsline{{toc}}{{subsection}}{{{content}}}")
                else:
                    out.append(f"\\subsection{{{content}}}")
            else:
                if unnumbered:
                    out.append(f"\\subsubsection*{{{content}}}")
                    out.append(f"\\addcontentsline{{toc}}{{subsubsection}}{{{content}}}")
                else:
                    out.append(f"\\subsubsection{{{content}}}")
            continue

        mnum = re.match(r"^\d+[.\)]\s+(.*)$", stripped)
        mbul = re.match(r"^[-*]\s+(.*)$", stripped)

        if in_refs and (mnum or mbul):
            content = _inline_format((mnum or mbul).group(1))
            close_lists()
            out.append(f"\\par\\noindent\\hangindent=1cm\\hangafter=1 {content}\\par\\vspace{{6pt}}")
            continue

        if mnum:
            if in_list:
                out.append("\\end{itemize}")
                in_list = False
            if not in_numlist:
                out.append("\\begin{enumerate}")
                in_numlist = True
            out.append(f"\\item {_inline_format(mnum.group(1))}")
            continue

        if mbul:
            if in_numlist:
                out.append("\\end{enumerate}")
                in_numlist = False
            if not in_list:
                out.append("\\begin{itemize}")
                in_list = True
            out.append(f"\\item {_inline_format(mbul.group(1))}")
            continue

        if stripped.startswith("> "):
            close_lists()
            out.append(f"\\begin{{quote}}{_inline_format(stripped[2:])}\\end{{quote}}")
            continue

        if re.match(r"^-{3,}$", stripped) or re.match(r"^\*{3,}$", stripped):
            close_lists()
            out.append("\\bigskip\\hrule\\bigskip")
            continue

        close_lists()
        out.append(_inline_format(stripped))

    close_lists()
    return "\n\n".join(out)


@app.get("/api/project/new")
def project_new(titulo: str = Query("consulta")):
    pid = datetime.now().strftime("P%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:6]
    pasta = PROJETOS_DIR / pid
    pasta.mkdir(parents=True)
    (pasta / "conversa.md").write_text(f"# {titulo}\n\n", encoding="utf-8")
    (pasta / "metadata.json").write_text(json.dumps({
        "id": pid, "titulo": titulo, "data": datetime.now().isoformat(),
        "modelo": MODEL, "mensagens": 0
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"project_id": pid, "path": str(pasta)}


class SaveRequest(BaseModel):
    prompt: str
    resposta: str
    tokens_input: int = 0
    tokens_output: int = 0
    elapsed: float = 0.0
    cost: float = 0.0


def _gerar_arquivos_consulta(pasta: Path, pid: str, prefix: str, prompt: str, resposta: str,
                              tokens_input: int, tokens_output: int, elapsed: float, cost: float) -> dict:
    """Gera os arquivos .md e .tex de uma consulta dentro da pasta do projeto.
    `prefix` diferencia a origem: 'consulta' (chat rápido, sem orquestrador) ou
    'dissertacao' (gerada em segundo plano via --agent marceloclaro)."""
    ts = datetime.now().strftime("%H%M%S")
    md = pasta / f"{prefix}-{ts}.md"
    md.write_text(
        f"## {prefix.capitalize()} ({datetime.now().strftime('%d/%m/%Y %H:%M')})\n\n"
        f"**Pergunta:**\n{prompt}\n\n"
        f"**Resposta:**\n{resposta}\n\n"
        f"---\n*Tokens: {tokens_input} in / {tokens_output} out | "
        f"Tempo: {elapsed}s | Custo: R$ {cost:.6f}*\n\n",
        encoding="utf-8"
    )

    san = _sanitize_filename(prompt[:80])
    tex_name = f"relatorio-{ts}.tex" if prefix == "consulta" else f"relatorio-{prefix}-{ts}.tex"
    tex_path = pasta / tex_name
    try:
        tex_template = TEMPLATE_TEX.read_text("utf-8") if TEMPLATE_TEX.exists() else ""
    except Exception:
        tex_template = ""
    if tex_template:
        subs = {
            "VAR_TITULO": _tex_escape(san),
            "VAR_DATA": datetime.now().strftime("%d/%m/%Y %H:%M"),
            "VAR_PROJETO_ID": pid,
            "VAR_PROMPT": _tex_escape(prompt),
            "VAR_RESPOSTA": markdown_to_latex(resposta),
            "VAR_TOKENS_INPUT": str(tokens_input),
            "VAR_TOKENS_OUTPUT": str(tokens_output),
            "VAR_ELAPSED": str(elapsed),
            "VAR_CUSTO": f"{cost:.6f}",
        }
        for k, v in subs.items():
            tex_template = tex_template.replace(k, v)
        tex_path.write_text(tex_template, encoding="utf-8")
    else:
        tex_path.write_text("Sem template LaTeX disponível", encoding="utf-8")

    return {"md": md.name, "tex": tex_path.name}


@app.post("/api/project/{pid}/save")
def project_save(pid: str, req: SaveRequest):
    pasta = PROJETOS_DIR / pid
    if not pasta.exists():
        raise HTTPException(404, "Projeto não encontrado")

    # Atualiza metadata
    meta_path = pasta / "metadata.json"
    meta = json.loads(meta_path.read_text("utf-8")) if meta_path.exists() else {}
    meta["mensagens"] = meta.get("mensagens", 0) + 1
    meta["ultima_consulta"] = datetime.now().isoformat()
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    files = _gerar_arquivos_consulta(
        pasta, pid, "consulta", req.prompt, req.resposta,
        req.tokens_input, req.tokens_output, req.elapsed, req.cost,
    )
    return {"status": "ok", "files": files}


@app.get("/api/project/{pid}/compile")
def project_compile(pid: str):
    pasta = PROJETOS_DIR / pid
    if not pasta.exists():
        raise HTTPException(404, "Projeto não encontrado")
    tex_files = list(pasta.glob("relatorio-*.tex"))
    if not tex_files:
        raise HTTPException(404, "Nenhum .tex para compilar")
    results = [_compilar_tex(pasta, tf) for tf in tex_files]
    return {"project_id": pid, "results": results}


def _compilar_tex(pasta: Path, tf: Path) -> dict:
    pdf = tf.with_suffix(".pdf")
    try:
        r = subprocess.run(
            ["pdflatex", "-interaction=nonstopmode", "-output-directory", str(pasta), str(tf)],
            capture_output=True, timeout=60, cwd=str(pasta)
        )
        log = r.stdout.decode("utf-8", errors="replace")[-600:]
        ok = pdf.exists() and pdf.stat().st_size > 0
        return {"file": tf.name, "pdf": pdf.name if ok else None, "ok": ok,
                "log": log if not ok else ""}
    except Exception as e:
        return {"file": tf.name, "pdf": None, "ok": False, "error": str(e)}


# ── Dissertação completa em segundo plano (--agent marceloclaro) ──────
# O chat rápido (/api/terminal) NÃO usa o orquestrador /marceloclaro por
# padrão — ele pode levar vários minutos até o primeiro token, o que não
# é aceitável para um quiosque interativo. Para quem quer o tratamento
# acadêmico completo (dissertação orquestrada, citações revisadas pelo
# pipeline multi-agente), esta rota gera o documento em background e o
# cliente consulta o status via polling, sem bloquear o chat.

def _dissertacao_status_path(pasta: Path) -> Path:
    return pasta / "dissertacao_status.json"


def _ler_status_dissertacao(pasta: Path) -> dict:
    p = _dissertacao_status_path(pasta)
    if not p.exists():
        return {"status": "nao_iniciado"}
    try:
        return json.loads(p.read_text("utf-8"))
    except Exception:
        return {"status": "nao_iniciado"}


def _escrever_status_dissertacao(pasta: Path, status: dict) -> None:
    _dissertacao_status_path(pasta).write_text(
        json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8"
    )


async def _gerar_dissertacao_bg(pid: str, prompt: str, model: str) -> None:
    pasta = PROJETOS_DIR / pid
    _escrever_status_dissertacao(pasta, {
        "status": "processando",
        "iniciado_em": datetime.now().isoformat(),
        "prompt": prompt,
    })
    start = time.time()
    full_prompt = f"{SYSTEM_CONTEXT}\n\n---\n\n{prompt}"
    try:
        result, error, ti, to, cost = await _run_opencode(full_prompt, model, agent=AGENT)
    except Exception as e:
        _escrever_status_dissertacao(pasta, {"status": "erro", "mensagem": str(e)})
        return

    elapsed = round(time.time() - start, 1)
    if error or not result:
        _escrever_status_dissertacao(pasta, {
            "status": "erro",
            "mensagem": error or "O orquestrador respondeu vazio.",
            "elapsed": elapsed,
        })
        return

    files = _gerar_arquivos_consulta(pasta, pid, "dissertacao", prompt, result, ti, to, elapsed, cost)
    tex_path = pasta / files["tex"]
    compile_result = _compilar_tex(pasta, tex_path)

    meta_path = pasta / "metadata.json"
    meta = json.loads(meta_path.read_text("utf-8")) if meta_path.exists() else {}
    meta["mensagens"] = meta.get("mensagens", 0) + 1
    meta["ultima_consulta"] = datetime.now().isoformat()
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    _escrever_status_dissertacao(pasta, {
        "status": "concluido",
        "concluido_em": datetime.now().isoformat(),
        "elapsed": elapsed,
        "tokens_input": ti,
        "tokens_output": to,
        "cost": cost,
        "md": files["md"],
        "tex": files["tex"],
        "pdf": compile_result.get("pdf"),
        "pdf_ok": compile_result.get("ok", False),
    })


class DissertacaoRequest(BaseModel):
    prompt: str
    model: str = ""


@app.post("/api/project/{pid}/dissertacao")
async def project_dissertacao(pid: str, req: DissertacaoRequest):
    pasta = PROJETOS_DIR / pid
    if not pasta.exists():
        raise HTTPException(404, "Projeto não encontrado")
    if not OPENCODE_BIN or not os.path.isfile(OPENCODE_BIN):
        raise HTTPException(status_code=503, detail="OpenCode CLI não encontrado")

    status_atual = _ler_status_dissertacao(pasta)
    if status_atual.get("status") == "processando":
        return {"status": "processando", "mensagem": "Já existe uma dissertação sendo gerada para este projeto."}

    model = _get_model(req.model)
    asyncio.create_task(_gerar_dissertacao_bg(pid, req.prompt, model))
    return {"status": "processando"}


@app.get("/api/project/{pid}/dissertacao/status")
def project_dissertacao_status(pid: str):
    pasta = PROJETOS_DIR / pid
    if not pasta.exists():
        raise HTTPException(404, "Projeto não encontrado")
    return _ler_status_dissertacao(pasta)


@app.get("/api/project/{pid}/files")
def project_files(pid: str):
    pasta = PROJETOS_DIR / pid
    if not pasta.exists():
        raise HTTPException(404, "Projeto não encontrado")
    files = []
    for f in sorted(pasta.iterdir()):
        if f.is_file() and f.name not in ("metadata.json",):
            files.append({"name": f.name, "size": f.stat().st_size,
                          "ext": f.suffix.lstrip("."), "modified": datetime.fromtimestamp(f.stat().st_mtime).isoformat()})
    return {"project_id": pid, "files": files, "total": len(files)}


@app.get("/api/project/{pid}/file/{name:path}")
def project_file(pid: str, name: str):
    pasta = PROJETOS_DIR / pid
    if not pasta.exists():
        raise HTTPException(404, "Projeto não encontrado")
    fpath = pasta / name
    if not fpath.exists() or not fpath.is_file():
        raise HTTPException(404, "Arquivo não encontrado")
    media = {
        "md": "text/markdown; charset=utf-8",
        "tex": "text/plain; charset=utf-8",
        "pdf": "application/pdf",
        "json": "application/json",
        "zip": "application/zip",
    }
    ext = fpath.suffix.lstrip(".").lower()
    return FileResponse(str(fpath), media_type=media.get(ext, "application/octet-stream"),
                        filename=fpath.name)


@app.get("/api/project/{pid}/zip")
def project_zip(pid: str):
    pasta = PROJETOS_DIR / pid
    if not pasta.exists():
        raise HTTPException(404, "Projeto não encontrado")
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(pasta.iterdir()):
            if f.is_file() and f.name != "metadata.json":
                zf.write(f, f.name)
    buf.seek(0)
    from fastapi.responses import Response
    return Response(buf.getvalue(), media_type="application/zip",
                    headers={"Content-Disposition": f"attachment; filename={pid}.zip"})


@app.get("/api/projects")
def project_list():
    projetos = []
    for p in sorted(PROJETOS_DIR.iterdir(), reverse=True):
        if p.is_dir():
            meta_path = p / "metadata.json"
            meta = json.loads(meta_path.read_text("utf-8")) if meta_path.exists() else {}
            md_count = len(list(p.glob("consulta-*.md")))
            tex_count = len(list(p.glob("relatorio-*.tex")))
            pdf_count = len(list(p.glob("relatorio-*.pdf")))
            projetos.append({
                "id": p.name,
                "titulo": meta.get("titulo", p.name),
                "data": meta.get("data", ""),
                "mensagens": meta.get("mensagens", md_count),
                "arquivos": {"md": md_count, "tex": tex_count, "pdf": pdf_count},
            })
    return {"projetos": projetos, "total": len(projetos)}


@app.delete("/api/project/{pid}")
def project_delete(pid: str):
    pasta = PROJETOS_DIR / pid
    if not pasta.exists():
        raise HTTPException(404, "Projeto não encontrado")
    shutil.rmtree(pasta)
    return {"status": "ok", "project_id": pid, "message": "Projeto removido"}


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", "8082"))
    host = os.environ.get("HOST", "127.0.0.1")
    uvicorn.run(app, host=host, port=port)
