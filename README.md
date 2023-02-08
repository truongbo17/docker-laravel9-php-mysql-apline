### Build docker Laravel 9 with PHP-fpm, Apline Linux, MySQL
**Control everything that you run**

* Config cron and supervisord in : `.docker/cron` & `.docker/supervisord` or `Dockerfile`
* Build docker : `docker-compose build`
* Run docker : `docker-compose up -d`
* Docker : `docker exec -it laravel-app /bin/sh`