docker-build:
	docker build -t devoptimus/admin-composer --target=admin_composer .
	docker build -t devoptimus/admin-fronted --target=admin_frontend .
	docker build -t devoptimus/admin-cli --target=admin_cli .
	docker build -t devoptimus/admin-fpm --target=admin_fpm .
	docker build -t devoptimus/admin-nginx --target=admin_nginx .
	docker build -t devoptimus/admin-cron --target=admin_cron .
docker-build-up:
	docker compose up --build
docker-up:
	docker compose up -d
docker-test:
	
	docker run --rm -d -v $(shell pwd)/test:/home/app/public_html \
		--network lan-test \
		--name php-fpm-test devoptimus/php-fpm
	
	docker run --rm -d -p 8900:80/tcp \
		-v $(shell pwd)/test:/home/app/public_html \
		-v $(shell pwd)/test/default.template:/etc/nginx/template.d/default.template \
		--network lan-test \
		--name nginx-test devoptimus/nginx
