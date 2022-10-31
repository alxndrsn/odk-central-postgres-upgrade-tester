FROM ubuntu:latest

RUN apt-get update
RUN apt-get install -y git

COPY . .

CMD ./test-migration
