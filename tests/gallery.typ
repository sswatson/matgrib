// Visual check of every spec in out/gallery.json (written by smoke_dsl.m).
// Compile from the repo root: typst compile --root . tests/gallery.typ
#import "../_extensions/matgrib/matgrib.typ": *
#set page(width: 17cm, height: auto, margin: 1cm)
#set text(font: "TeX Gyre Pagella", size: 10pt)
#for item in json("out/gallery.json") {
  block(breakable: false)[
    #text(weight: "bold", item.name)
    #matgrib-figure(item.spec)
  ]
  v(0.8em)
}
