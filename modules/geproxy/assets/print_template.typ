#import "@preview/tiaoma:0.3.0": code128

#set page(margin: 2cm)
#set text(size: 14pt)
#set align(center + horizon)

#let team = sys.inputs.at("team_name", default: "Not found")
#let ip = sys.inputs.at("requesting_ip", default: "")

#let map = sys.inputs.at("map", default: "")
#let team = sys.inputs.at("name", default: "Not found")
#let ip = sys.inputs.at("requesting_ip", default: "")
// Set by the balloons webhook ("P<id>"); scanning it at the balloons desk
// marks this print delivered.
#let print-job = sys.inputs.at("print_job_id", default: "")

#if map != "" {
  image(map, width: 60%)
  v(0.5cm)
}

#text(size: 24pt, weight: "bold")[#team]
#v(0.5cm)

#linebreak()
#text[IP: #ip]

#if print-job != "" {
  v(1cm)
  code128(print-job, width: 6cm)
}
