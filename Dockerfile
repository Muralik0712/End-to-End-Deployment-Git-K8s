FROM tomcat:latest
COPY taxi-booking/target/taxi-booking-1.0.1.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
