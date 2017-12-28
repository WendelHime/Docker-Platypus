#!/usr/bin/env python3
import os
import re
import argparse

def replaceLine(filepath, regex, replace):
    """ (str, str, str) -> (none)
        Method used to replace line
    """
    fh = open(filepath, "r")
    content = fh.read()
    fh.close()
    regex = re.compile(regex)
    content = regex.sub(replace, content)
    fh = open(filepath, "w")
    fh.writelines(content)
    fh.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="This is a auxiliar script responsible to run result applications from report_html_db.pl in Docker.")
    parser.add_argument("organism", type=str, help="Organism first name")
    parser.add_argument("type", type=str, help="Application type to be runned", choices=['website', 'service'])
    parser.add_argument("--restendpoint", type=str, help="Services REST endpoint URL, if you're running website, this is required")
    parser.add_argument("--dbname", type=str, help="Database name")
    parser.add_argument("--dbhost", type=str, help="Database host URL")
    parser.add_argument("--dbusername", type=str, help="Database username")
    parser.add_argument("--dbpassword", type=str, help="Database password")
    args = parser.parse_args()

    if(args.type == "website"):
        replaceLine("/" + args.organism + "-Website/" + args.organism.lower() + "_website.conf", 
                "rest_endpoint ([\w:/.]+)+", 
                "rest_endpoint "+args.restendpoint)
        replaceLine("/" + args.organism + "-Website/lib/" + args.organism + "/Website/Model/Basic.pm", 
                "dsn => 'dbi:SQLite:([/\w\-.]+)+'", 
                "dsn => 'dbi:SQLite:/"+args.organism+"-Website/database.db'")
        os.system("./"+args.organism + "-Website/script/" + args.organism.lower() + "_website_server.pl -p 80 -r")
    elif(args.type == "service"):    
        replaceLine("/" + args.organism + "-Services/lib/"+args.organism+"/Services/Model/SearchDatabaseRepository.pm", 
                "dsn\s*=>\s*\"dbi:Pg:dbname=\w+;host=\w+\"", 
                "dsn      => \"dbi:Pg:dbname="+args.dbname+";host="+args.dbhost+"\"")
        replaceLine("/" + args.organism + "-Services/lib/"+args.organism+"/Services/Model/SearchDatabaseRepository.pm", 
                "user\s*=>\s*\"\w+\"",
                "user     => \""+args.dbusername+"\"")
        replaceLine("/" + args.organism + "-Services/lib/"+args.organism+"/Services/Model/SearchDatabaseRepository.pm", 
                "password\s*=>\s*\"\w+\"",
                "password => \""+args.dbpassword+"\"")
        os.system("./"+args.organism + "-Services/script/" + args.organism.lower() + "_services_server.pl -p 80 -r ")

