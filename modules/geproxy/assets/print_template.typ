#set page(margin: 2cm)
#set text(size: 14pt)
#set align(center + horizon)

#let team = sys.inputs.at("team_name", default: "Not found")
#let ip = sys.inputs.at("requesting_ip", default: "")

#text(size: 24pt, weight: "bold")[#team]
#v(0.5cm)

#linebreak()
#text[IP: #ip]
