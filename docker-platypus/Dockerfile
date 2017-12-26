####
#
# This Dockerfile is dedicated to create an ambient for the applications Services and Website
#
####
FROM debian:stretch
MAINTAINER Wendel Hime Lino Castro <wendelhime@hotmail.com>

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y build-essential wget apt-utils libpq-dev gcc vim curl ssh perl-base perl perl-doc

RUN wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/LATEST/ncbi-blast-2.6.0+-x64-linux.tar.gz
RUN tar zxvpf ncbi-blast-2.6.0+-x64-linux.tar.gz

RUN apt-get install -y libfile-find-rule-perl sqlite3 libdbd-pg-perl postgresql-9.6
RUN PERL_MM_USE_DEFAULT=1 cpan CPAN
RUN PERL_MM_USE_DEFAULT=1 cpan Class::Load Class::Load::PP

RUN PERL_MM_USE_DEFAULT=1 cpan Class::Load::XS Class::MOP Data::OptList
RUN PERL_MM_USE_DEFAULT=1 cpan Moose Moose::Role Moose::Exporter Moose::Util::TypeConstraint
RUN PERL_MM_USE_DEFAULT=1 cpan DBIx::Class DBD::Pg Catalyst::Devel Catalyst::Runtime YAML Archive::Zip File::Find::Rule 
RUN PERL_MM_USE_DEFAULT=1 cpan Catalyst::Action::REST Catalyst::ScriptRunner  Catalyst::View::TT Catalyst::View::JSON Catalyst::Model::DBIC::Schema DBIx::Class::Schema::Loader MooseX::NonMoose DBIx::Class::Helper::ResultSet::SetOperations Catalyst::Restarter Catalyst::Model::Adaptor Catalyst::Model::DBI MooseX::Storage Catalyst::Controller::REST Catalyst::Model::DBIC::Schema Archive::Zip 

RUN PERL_MM_USE_DEFAULT=1 cpan Capture::Tiny DBI Task::Catalyst Task::Plack Reindeer

RUN PERL_MM_USE_DEFAULT=1 cpan SQL::Library Catalyst::Model::DBI::SQL::Library Catalyst::Model::DBI 

ADD egene2-code /usr/local/genome/egene2/bin
RUN export PATH=$PATH:/usr/local/genome/egene2/bin
RUN export PATH=$PATH:ncbi-blast-2.6.0+/bin
RUN export PERL5LIB=$PERL5LIB:/usr/local/genome/egene2/bin

EXPOSE 80 


