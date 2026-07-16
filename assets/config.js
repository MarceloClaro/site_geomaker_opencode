window.GEOMAKER_CONFIG = {
  // Informe a URL pública do WordPress que contém o Tainacan.
  // Exemplo: "https://acervo.geomaker.org"
  tainacanBaseUrl: "",

  // Informe o ID numérico da coleção pública do Tainacan.
  tainacanCollectionId: "",

  // Endereço do painel administrativo usado pela equipe para cadastrar itens.
  // Pode ser a entrada do WordPress: "https://acervo.geomaker.org/wp-admin/"
  // ou a URL da coleção copiada diretamente do painel do Tainacan.
  tainacanAdminUrl: "",

  // Como alternativa, informe diretamente o endpoint público de itens.
  // Exemplo: "https://acervo.exemplo.org/wp-json/tainacan/v2/collection/12/items"
  tainacanItemsEndpoint: "",

  // Servidor TouchTerrain instalado pelo pacote WSL.
  // O site fica em localhost:8080 e o gerador local em localhost:8081.
  touchTerrainBaseUrl: "/touchterrain",

  // Endereço que receberá os pedidos de visita quando o formulário for publicado.
  // Enquanto estiver vazio, o protótipo baixa uma cópia local da solicitação.
  contactEmail: "",

  museumName: "Museu Escolar Itinerante Geomaker",
  location: "Crateús, Ceará"
};
