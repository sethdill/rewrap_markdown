BEGIN {
	RS = ""
	ORS = "\n\n"
}

NR == 1 {
	print
	next
}

{
	paragraph = $0
	gsub(/\n[[:space:]]*/, " ", paragraph)
	print paragraph
}
