.PHONY: clean clean-all logs run stat stop
.SILENT:

PROJECT_NAME			= the-app
DOCKER_COMPOSE_COMMAND	= docker compose -p "$(PROJECT_NAME)"

# Detect the OS we're running on.
ifeq ($(OS),Windows_NT)
	detected_OS := Windows
else
	detected_OS := $(shell uname -s)
endif


clean:
	$(DOCKER_COMPOSE_COMMAND) rm -sf

clean-all: clean
	docker system prune -f --volumes

logs: run
	$(DOCKER_COMPOSE_COMMAND) logs -f

run:
# If we're on linux, let's override permissions to the volume so we can actually
# use the development environment with local mount points without permissios
# issues.
ifeq ($(detected_OS), Linux)
	UID=$(shell id -u) GID=$(shell id -g) \
	$(DOCKER_COMPOSE_COMMAND) \
	-f docker-compose.yml \
	-f docker-compose.permissions.yml \
 	up --detach
else
	$(DOCKER_COMPOSE_COMMAND) up --detach
endif

stat:
	echo "\n ------- containers "
	$(DOCKER_COMPOSE_COMMAND) ps -a
	echo "\n ------- volumes "
	docker volume ls
	echo "\n ------- images "
	docker images -a

stop: pgadmin.stop postgres.stop backend.stop



.PHONY: backend.build backend.restart backend.stop backend.test

backend.build:
	$(DOCKER_COMPOSE_COMMAND) build


backend.restart:
	$(DOCKER_COMPOSE_COMMAND) up -d --force-recreate backend

backend.shell:
	$(DOCKER_COMPOSE_COMMAND) exec backend \
		/bin/sh

backend.stop:
	$(DOCKER_COMPOSE_COMMAND) stop backend

backend.test: run
	$(DOCKER_COMPOSE_COMMAND) exec backend \
		sh -c './manage.py test'



.PHONY: postgres.start postgres.stop

postgres.start:
	$(DOCKER_COMPOSE_COMMAND) up -d postgres
	$(DOCKER_COMPOSE_COMMAND) exec postgres \
		sh -c 'while ! nc -z postgres 5432; do sleep 0.1; done'

postgres.stop:
	$(DOCKER_COMPOSE_COMMAND) stop postgres



.PHONY: pgadmin.start pgadmin.stop

pgadmin.start: postgres.start
	$(DOCKER_COMPOSE_COMMAND) up -d pgadmin
	$(DOCKER_COMPOSE_COMMAND) exec pgadmin \
		sh -c 'while ! nc -z pgadmin 80; do sleep 0.1; done'

pgadmin.stop:
	$(DOCKER_COMPOSE_COMMAND) stop pgadmin



.PHONY: django.createsuperuser django.init-db django.migrate django.shell

django.createsuperuser: postgres.start
	$(DOCKER_COMPOSE_COMMAND) exec \
		-e DJANGO_SUPERUSER_USERNAME=admin \
		-e DJANGO_SUPERUSER_PASSWORD=admin \
		-e DJANGO_SUPERUSER_EMAIL=admin@example.com \
		backend \
		sh -c './manage.py createsuperuser --noinput'

django.init-db: django.migrate django.createsuperuser
	echo "... TODO: load fixtures ..."

django.migrate: postgres.start
	$(DOCKER_COMPOSE_COMMAND) exec backend \
		sh -c './manage.py migrate'

django.shell:
	$(DOCKER_COMPOSE_COMMAND) exec backend \
		sh -c './manage.py shell'

