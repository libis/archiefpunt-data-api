#!/bin/bash

if [ ! -f ".env" ]; then
   echo "Please create an .env file with a SERVICE, REGISTRY and NAMESPACE parameter"
   exit 1
fi

source .env

if [ -z $REGISTRY ]; then
   echo "Please set REGISTRY in .env"
   exit 1
fi

if [ -z $SERVICE ]; then
   echo "Please set SERVICE in .env"
   exit 1
fi

if [ -z $NAMESPACE ]; then
   echo "Please set NAMESPACE in .env"
   exit 1
fi

function build {
   echo "Building $SERVICE"
   docker build -f Dockerfile --tag $NAMESPACE/$SERVICE .
}

function push {
   echo "Pushing $SERVICE"
   docker tag $NAMESPACE/$SERVICE $REGISTRY/$NAMESPACE/$SERVICE
   docker push $REGISTRY/$NAMESPACE/$SERVICE
}

case $1 in
"push")
  build
  push
  ;;
*)
  build
  ;;
esac

echo
echo
if [ -z "$DEBUG" ]; then
   echo "docker run -p 9292:9292 $NAMESPACE/$SERVICE"
else
   echo "docker run -p 1234:1234 -p 9292:9292 -e DEBUG=1 $NAMESPACE/$SERVICE"
fi
