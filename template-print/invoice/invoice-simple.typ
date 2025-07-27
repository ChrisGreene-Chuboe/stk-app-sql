// Simple Invoice Template - POC for chuck-stack
// Load JSON data from current directory (where typst is run)
#let invoice-data = json("invoice-data.json")

// Page setup
#set page(paper: "us-letter", margin: 2cm)
#set text(size: 10pt)

// Title
#align(center)[
  #text(size: 20pt, weight: "bold")[INVOICE]
]

#v(1em)

// Basic info
Invoice Number: #invoice-data.number \
Date: #invoice-data.date \
\
Bill To: #invoice-data.customer.name \

#v(2em)

// Line items header
#text(weight: "bold")[Line Items:]

// Simple line items listing
#for item in invoice-data.items [
  - #item.line - #item.description - "Qty:" #item.qty - "Price:" $#item.price - "Total:" $#item.total
]

#v(2em)

// Totals
"Subtotal:" $#invoice-data.subtotal \
"Total:" $#invoice-data.total