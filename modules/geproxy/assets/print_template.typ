#set page(margin: 2cm)
#set text(size: 14pt)
#set align(center + horizon)

#let team = sys.inputs.at("team_name", default: "Not found")
#let ip = sys.inputs.at("requesting_ip", default: "")

#let map = sys.inputs.at("map", default: "")
#let team = sys.inputs.at("name", default: "Not found")
#let ip = sys.inputs.at("requesting_ip", default: "")

#if map != "" {
  image(map, width: 60%)
  v(0.5cm)
}

#text(size: 24pt, weight: "bold")[#team]
#v(0.5cm)

#linebreak()
#text[IP: #ip]
