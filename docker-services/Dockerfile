####
#
# This Dockerfile is dedicated to a test with the application Services
#
####
FROM wendelhime/platypus:latest 

ADD curtobacterium.conf /etc/apache2/sites-available
ADD Curtobacterium-Services /var/www/Curtobacterium-Services
ADD curtobacterium_db.sql .

RUN a2enmod perl
RUN a2ensite curtobacterium
RUN a2dissite 000-default

EXPOSE 80 

RUN sed -e "s/[#]\?listen_addresses = .*/listen_addresses = '*'/g" -i '/etc/postgresql/9.6/main/postgresql.conf'
ADD pg_hba.conf /etc/postgresql/9.6/main
ADD intipostgres.sh /usr/local/sbin
ENTRYPOINT ["/usr/local/sbin/intipostgres.sh"]
RUN chmod +x /usr/local/sbin/intipostgres.sh
EXPOSE 5432
CMD ["apachectl", "-DFOREGROUND"]

