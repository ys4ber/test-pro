push:
	@git add .
	@echo -n "Enter commit message: "
	@read message; git commit -m "$$message"
	@git push