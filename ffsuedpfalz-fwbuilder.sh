#!/bin/bash

######################################################
# Doku
######################################################
#http://gluon.readthedocs.org/en/v2015.1.2/user/getting_started.html


######################################################
# Vor-Einstellungen
######################################################

# Anzahl der CPUs +1 für make -j 
_CPUs=$(($(cat /proc/cpuinfo |grep -c processor)+1))
# eigener privater ecdsa Key zum Signieren
_SECRETKEY=~/ecdsa_key_ffsuedpfalz





echo ""
echo "######################################################"
echo "Freifunk-Südpfalz Imagebuilder v.0.1.0"
echo "######################################################"
echo ""


######################################################"
# Abhänigkeiten checken"
######################################################"
echo "checke Abhänigkeiten..."
echo ""

_laeuft=true

if [[ $(which curl) ]]; then
  echo "OK curl ist da"
else
  echo "curl fehlt"
  _laeuft=false 
fi

if [[ $(which git) ]]; then
  echo "OK git ist da"
else
  echo "git fehlt"
  _laeuft=false 
fi

if [[ $(which ecdsasign) ]]; then
  echo "OK ecdsasign ist da"
else
  echo "ecdsasign fehlt"
  _laeuft=false
fi

#TODO alle Abhängikeiten checken

[[ ${_laeuft} ]] || exit;

#TODO fehlendes Zeugs installieren / erzeugen?
#apt-get -y install curl cmake git subversion make pkg-config build-essential unzip libncurses-dev gawk ......





######################################################
# Einstellungen
######################################################


# Gluon-Releases holen
_RELEASE_TAGS=$(curl -nsSi -H 'Accept: application/vnd.github.v3+json' -H 'Content-Type: application/json' -X GET https://api.github.com/repos/freifunk-gluon/gluon/releases | grep tag_name | cut -d'"' -f4 | tr '\n' ' ')
_LATEST_RELEASE=${_RELEASE_TAGS%% *}

echo "Aktuell verfügbare Gluon Versionen:"
echo ${_RELEASE_TAGS}

_GLUON_VERSION="notset"
# Gluon-Release-Tag im gluon github repository auswählen
while [[ ! $_RELEASE_TAGS =~ (^| )$_GLUON_VERSION($| ) ]]; do
  read -e -p "Gluon Version bauen: " -i "${_LATEST_RELEASE}" _GLUON_VERSION
done
echo ""

while [[ "$GLUON_BRANCH" != "stable" && "$GLUON_BRANCH" != "beta" && "$GLUON_BRANCH" != "experimental" ]]; do
  read -e -p "Firmware Branch ( stable | beta | experimental ) bauen: " -i "stable" GLUON_BRANCH
done
# mit GLUON_BRANCH wird Autoupdate aktiviert voreingestellt
export GLUON_BRANCH
echo ""

# Secret-key zum signieren der Manifestdatei
read -e -p "Dein privater ecdsa-key zum signieren der Manifestdatei: " -i ${_SECRETKEY} _SECRETKEY


_ANTWORT="notset"
while [[ ! ${_ANTWORT,,} =~ ^(ja|j|nein|n|)$ ]]; do
  read -e -p "Images für Freifunk-Suedpfalz bauen? [J/n] " _ANTWORT
done
if [[ ${_ANTWORT,,} =~ ^(ja|j|)$ ]];then
  _BAUE_FFSUEDPFALZ=1
fi

_ANTWORT="notset"
while [[ ! ${_ANTWORT,,} =~ ^(ja|j|nein|n|)$ ]]; do
  read -e -p "Images für Freifunk-Hassloch bauen? [J/n] " _ANTWORT
done
if [[ ${_ANTWORT,,} =~ ^(ja|j|)$ ]];then
  _BAUE_FFHASSLOCH=1
fi




echo ""
echo "######################################################"
echo "Gluon holen"
echo "######################################################"
echo ""

# absoluter Dateipfad zum gluon Ordner. Dieses Script muss eine ebene höher liegen ... TODO flexibler, fehlerunanfälliger machen
_GLUON_PATH=$(pwd)/gluon_${_GLUON_VERSION}


# Gluon holen
if [[ -d gluon_${_GLUON_VERSION} ]]; then
  echo "Ordner für Gluon {_GLUON_VERSION} schon vorhanden"
else
  echo "Clone Gluon {_GLUON_VERSION}"
  git clone --depth 1 -b ${_GLUON_VERSION} https://github.com/freifunk-gluon/gluon.git gluon_${_GLUON_VERSION}
fi

cd gluon_${_GLUON_VERSION}


echo ""
echo "######################################################"
echo "Sites holen, Images bauen, signieren und auf Webspace kopieren"
echo "######################################################"


#Images für Freifunk-Suedpfalz bauen
echo ""
echo ""

if [[ ${_BAUE_FFSUEDPFALZ} ]]; then
  if [[ -d site-ffsuedpfalz ]]; then
    echo "Ordner für site-ffsuedpfalz schon vorhanden"
    #TODO git pull?
  else
    echo "Clone site-ffsuedpfalz "
    git clone --depth 1 -b master https://github.com/freifunk-suedpfalz/site-ffsuedpfalz.git site-ffsuedpfalz
  fi
  export GLUON_SITEDIR=${_GLUON_PATH}/site-ffsuedpfalz

  export GLUON_IMAGEDIR=${_GLUON_PATH}/images-ffsuedpfalz
  if [[ -d ${GLUON_IMAGEDIR} ]];then
    #TODO nachfragen ob löschen?
    rm -rf ${GLUON_IMAGEDIR}
  fi

  # update
  echo $(date)
  echo "make update ..."
  make update
  echo ""

  # bauen
  echo $(date)
  echo "make -j ${_CPUs} GLUON_TARGET=ar71xx-generic ..."
  make -j ${_CPUs} GLUON_TARGET=ar71xx-generic
  echo ""

  # signieren
  make manifest
  contrib/sign.sh ${_SECRETKEY} ${GLUON_IMAGEDIR}/sysupgrade/${GLUON_BRANCH}.manifest
  # TODO Manifest zum Signieren ins git legen
  # TODO Auf Webspace kopieren
fi



#Images für Freifunk-Hassloch bauen
echo ""
echo ""

if [[ ${_BAUE_FFHASSLOCH} ]]; then
  if [[ -d site-ffhassloch ]]; then
    echo "Ordner für site-ffhassloch schon vorhanden"
    #TODO git pull?
  else
    echo "Clone site-ffhassloch"
    git clone --depth 1 -b ffhassloch https://github.com/freifunk-suedpfalz/site-ffsuedpfalz.git site-ffhassloch
  fi
  export GLUON_SITEDIR=${_GLUON_PATH}/site-ffhassloch
  export GLUON_IMAGEDIR=${_GLUON_PATH}/images-ffhassloch
  if [[ -d ${GLUON_IMAGEDIR} ]];then
    #TODO nachfragen ob löschen?
    rm -rf ${GLUON_IMAGEDIR}
  fi

  # update
  echo $(date)
  echo "make update ..."
  make update
  echo ""

  # bauen
  echo $(date)
  echo "make -j ${_CPUs} GLUON_TARGET=ar71xx-generic ..."
  make -j ${_CPUs} GLUON_TARGET=ar71xx-generic
  echo ""

  # signieren
  make manifest
  contrib/sign.sh ${_SECRETKEY} ${GLUON_IMAGEDIR}/sysupgrade/${GLUON_BRANCH}.manifest

  echo -e '\a'
  # TODO Manifest zum Signieren ins git legen
  # TODO Auf Webspace kopieren
fi




######################################################
#TODO
######################################################
# farbige ausgabe
# /etc/banner anpassen: gluon verion, fw verion adden
# script argumente einbauen




#make clean GLUON_TARGET=ar71xx-generic
#ecdsaverify -f fingerabdurck -p pukkeay fiel
# echo 3 > /proc/sys/vm/drop_caches
# sysupgrade ....



