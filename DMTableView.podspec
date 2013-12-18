Pod::Spec.new do |s|
  s.name            = 'DMTableView'
  s.author          = { "Dmitry Ponomarev" => "demdxx@gmail.com" }
  s.version         = '0.0.1-alpha'
  s.license         = 'MIT'
  s.homepage        = 'https://github.com/demdxx/DMTableView'
  s.source          = {
    :git => 'https://github.com/demdxx/DMTableView.git',
    :tag => 'v0.0.1-alpha'
  }
  
  s.source_files    = 'Classes/*.{m,h}'
  s.requires_arc    = true
  
  s.frameworks      = 'UIKit'
end