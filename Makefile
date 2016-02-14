build:
	docker build -t docker-volume-backup .
buildrestic:
	git clone https://github.com/restic/restic.git || true
	docker run --rm -v "$$PWD/restic":/usr/src/restic -w /usr/src/restic golang go run build.go
