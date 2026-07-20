require 'uri'
require 'open-uri'
require 'json'

# lat - north-south direction
# lon - west-east direction

lat0, lon0 = 48.60113, 19.29473 # left bottom
lat1, lon1 = 48.70047, 19.52991 # right top


lat_steps, lon_steps = 80, 24
lat_diff, lon_diff = ((lat1 - lat0) / lat_steps.to_f), ((lon1 - lon0) / lon_steps.to_f)

one_cm_in_pts = 33 # svg setup
z_cms = 6 # z-axis width between lowest and highest point will be 6 cm


############ get elevations from mapquestapi.com

uri = URI.parse('http://open.mapquestapi.com/elevation/v1/profile')
#  convert key http://www.w3schools.com/tags/ref_urlencode.asp
params = { 'key' => "your-key-here", 'shapeFormat' => "raw",   }

elevations = []

(0...lat_steps).each do |i|
  points = []
  lat = lat0 + lat_diff * i
  (0...lon_steps).each do |j|
    lon = lon0 + lon_diff * j
    points << lat
    points << lon
  end
  
  params['latLngCollection'] = points.join(',')
  uri.query = URI.encode_www_form params 
  response = uri.open.read
  json_response = JSON.parse response
  elevations << json_response['elevationProfile'].collect{|h| h['height']}
end
############## convert elevations from meters to pixels

ele_min, ele_max = elevations.flatten.min, elevations.flatten.max
ele_diff = (ele_max - ele_min).to_f

cm_to_svg_point_ratio = one_cm_in_pts * z_cms # 1.0 = 200 px = 6.0 cm
elevations_in_pixels = []
elevations.each do |eline|
  eline_relative = []
  eline.each do |e|
    eline_relative << ((1.0 - ((ele_max - e) / ele_diff)) * cm_to_svg_point_ratio).to_i
  end
  elevations_in_pixels << eline_relative
end

################ SLICING IN SOUTH-NORTH DIRECTION

svg_polylines = [] # for each of the 24 paper sheets we want to cut we will create a polyline and store all of them here
total_length_in_south_north_direction_in_cm = 10 #

y_offset_between_two_slices = 200 # points 
elevations_in_pixels = elevations_in_pixels.transpose 

x_offset_between_points = ((total_length_in_south_north_direction_in_cm / lat_steps.to_f) * one_cm_in_pts).to_i

(0...lon_steps).each do |i| # for each of the 24 papers sheets
  svg_polyline_points = []
  svg_polyline_points << [0, (y_offset_between_two_slices*i - one_cm_in_pts*2)]
  svg_polyline_points << [0, elevations_in_pixels[i][0] + y_offset_between_two_slices*i]
  
  (0...lat_steps).each do |j| # for each of the 80 elevation points of one sheet
    x = x_offset_between_points * j 
    y = elevations_in_pixels[i][j] + y_offset_between_two_slices*i
    svg_polyline_points << [x,y]
  end
  
  svg_polyline_points << [(x_offset_between_points * (lat_steps-1)), (y_offset_between_two_slices*i - one_cm_in_pts*2)]
  svg_polyline_points << [0, (y_offset_between_two_slices*i - one_cm_in_pts*2)]
  
  svg_polyline = "<polyline points=\"#{svg_polyline_points.collect{|a,b| "#{a},#{b}"}.join(' ')}\" style=\"fill:white;stroke:red;stroke-width:4\" />"
  svg_polylines << svg_polyline
end

(0...(lon_steps)).each do |i|
  
  (1...(lat_steps)).each do |j|
    next if j % 10 != 0

    svg_polyline_points = []
    x1 = x_offset_between_points * j
    y1 = y_offset_between_two_slices*i - one_cm_in_pts*2 - 1
    x0 = x1 
    y0 = y1 + one_cm_in_pts

    svg_polyline_points << [x1+6, y1]
    svg_polyline_points << [x1+1, y1+6]
    svg_polyline_points << [x0+1, y0]
    svg_polyline_points << [x0-1, y0]
    svg_polyline_points << [x1-1, y1+6]
    svg_polyline_points << [x1-6, y1]
    svg_polyline = "<polyline points=\"#{svg_polyline_points.collect{|a,b| "#{a},#{b}"}.join(' ')}\" style=\"fill:white;stroke:red;stroke-width:4\" />"
    svg_polylines << svg_polyline
  end
end


svg_template = File.read 'template-cut.svg'
svg = svg_template.sub 'POLYLINES_HERE', svg_polylines.join("\n")
File.open('out.svg', 'w'){|f| f.write svg}