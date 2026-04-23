#set page(margin: 2cm)
#set text(size: 14pt)
#set align(center + horizon)

#let logo = sys.inputs.at("logo", default: "")
#let team = sys.inputs.at("team_name", default: "Not found")
#let ip = sys.inputs.at("requesting_ip", default: "")

#if logo != "" {
  image(logo, width: 60%)
  v(0.5cm)
}

#text(size: 24pt, weight: "bold")[#team]
#v(0.5cm)

#linebreak()
#text[IP: #ip]
