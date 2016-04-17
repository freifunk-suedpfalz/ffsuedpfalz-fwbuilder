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
echo "Freifunk-Südpfalz Firmwarebuilder v.0.1.1"
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
#apt-get -y install curl cmake git subversion make pkg-config build-essential unzip libncurses-dev gawk libssl-dev......





######################################################
# Einstellungen
######################################################


# Gluon-Releases holen
_RELEASE_TAGS=$(curl -nsSi -H 'Accept: application/vnd.github.v3+json' -H 'Content-Type: application/json' -X GET https://api.github.com/repos/freifunk-gluon/gluon/releases | grep tag_name | cut -d'"' -f4 | tr '\n' ' ')
_LATEST_RELEASE=${_RELEASE_TAGS%% *}

# master hinzufügen
_RELEASE_TAGS="master ${_RELEASE_TAGS}"

echo "Aktuell verfügbare Gluon Versionen:"
echo ${_RELEASE_TAGS}

# Gluon Version auswählen
_GLUON_VERSION="notset"
# Gluon-Release-Tag im gluon github repository auswählen
while [[ ! $_RELEASE_TAGS =~ (^| )$_GLUON_VERSION($| ) ]]; do
  read -e -p "Gluon Version bauen: " -i "${_LATEST_RELEASE}" _GLUON_VERSION
done
echo ""

# Gluon Branch auswählen, stable beta oder experimental
while [[ "$GLUON_BRANCH" != "stable" && "$GLUON_BRANCH" != "beta" && "$GLUON_BRANCH" != "experimental" ]]; do
  read -e -p "Firmware Branch ( stable | beta | experimental ) bauen: " -i "stable" GLUON_BRANCH
done
# mit export GLUON_BRANCH wird Autoupdate aktiviert voreingestellt
export GLUON_BRANCH
echo ""

# Build Target auswählen
# ar71xx-generic ar71xx-nand mpc85xx-generic x86-generic x86-kvm_guest x86-64 x86-xen_domu
while [[ "$GLUON_TARGET" != "ar71xx-generic" && "$GLUON_TARGET" != "ar71xx-nand" && "$GLUON_TARGET" != "mpc85xx-generic" && "$GLUON_TARGET" != "x86-generic" && "$GLUON_TARGET" != "x86-kvm_guest" && "$GLUON_TARGET" != "x86-64" && "$GLUON_TARGET" != "x86-xen_domu" ]]; do
  read -e -p "Gluon Target ( ar71xx-generic | ar71xx-nand | mpc85xx-generic | x86-generic | x86-kvm_guest | x86-64 | x86-xen_domu ) bauen: " -i "ar71xx-generic" GLUON_TARGET
done
export GLUON_TARGET

# Secret-key zum signieren der Manifestdatei
read -e -p "Dein privater ecdsa-key zum signieren der Manifestdatei: " -i ${_SECRETKEY} _SECRETKEY

# Verbose Ausgaben beim bauen?
_ANTWORT="notset"
_VERBOSE=""
while [[ ! ${_ANTWORT,,} =~ ^(ja|j|nein|n|)$ ]]; do
  read -e -p "make mit V=s starten? [J/n] " _ANTWORT
done
if [[ ${_ANTWORT,,} =~ ^(ja|j|)$ ]];then
  _VERBOSE="V=s"
fi



######################################################
# Community Images
######################################################

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

_GLUON_PATH=$(pwd)/gluon_${_GLUON_VERSION}


# Gluon holen
if [[ -d ${_GLUON_PATH} ]]; then
  echo "Ordner für Gluon ${_GLUON_VERSION} schon vorhanden. git pull..."
  cd ${_GLUON_PATH}
  git pull
else
  echo "Clone Gluon ${_GLUON_VERSION}"
  git clone --depth 1 -b ${_GLUON_VERSION} https://github.com/freifunk-gluon/gluon.git gluon_${_GLUON_VERSION}
fi

cd ${_GLUON_PATH}

echo ""
echo "######################################################"
echo "Sites holen, Images bauen und signieren"
echo "######################################################"


_SITE_VERSION=${_GLUON_VERSION}


#Images für Freifunk-Suedpfalz bauen
echo ""
echo ""

if [[ ${_BAUE_FFSUEDPFALZ} ]]; then
  if [[ -d site-ffsuedpfalz ]]; then
    echo "Ordner für site-ffsuedpfalz schon vorhanden. git pull..."
    cd site-ffsuedpfalz
    git pull
    cd ..
  else
    echo "Clone site-ffsuedpfalz "
    git clone --depth 1 -b ${_SITE_VERSION} https://github.com/freifunk-suedpfalz/site-ffsuedpfalz.git site-ffsuedpfalz
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
  #make clean GLUON_TARGET=ar71xx-generic
  echo ""

  # bauen
  echo $(date)
  make ${_VERBOSE} -j ${_CPUs} GLUON_TARGET=ar71xx-generic
  echo ""

  # TODO bei Fehler make nochmal mit V=s starten

  # TODO nur signieren wenn make durchlief
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
    echo "Ordner für site-ffhassloch schon vorhanden. git pull..."
    cd site-ffhassloch
    git pull
    cd ..
  else
    echo "Clone site-ffhassloch"
    git clone --depth 1 -b ffhassloch-${_SITE_VERSION} https://github.com/freifunk-suedpfalz/site-ffsuedpfalz.git site-ffhassloch
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
  #make clean GLUON_TARGET=ar71xx-generic
  echo ""

  # bauen
  echo $(date)
  make ${_VERBOSE} -j ${_CPUs} GLUON_TARGET=ar71xx-generic
  echo ""

  # TODO bei Fehler make nochmal mit V=s starten

  # TODO nur signieren wenn make durchlief
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



#notitzen
#make clean GLUON_TARGET=ar71xx-generic
#ecdsaverify -f fingerabdurck -p pukkeay fiel
# echo 3 > /proc/sys/vm/drop_caches
# sysupgrade ....
