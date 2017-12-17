#!/bin/bash

## Desenvolvedor: Marcelo S. Camacho
## Laboratório de Computação Científica - UNIFESSPA


COMPRIMIDOS=$(ls | grep zip)

# Usuário e senha do banco de dados
USUARIO=username
PGPASSWORD=mypass

# O pegará a lista de arquivos no diretório e descompactará em um novo diretório aqui chamado de TO_LOAD. Depois disso, converterá para UTF-8 e fará o tratamento para a carga.

find -name '*.zip' -exec sh -c 'unzip -d "${1%.*}" "$1"' _ {} \;
find . -iname "*.rar" -type f -execdir unrar x {} \;

if [ -d "TO_LOAD" ]
then
	rm -rf TO_LOAD
else
	mkdir TO_LOAD
fi;

FILES=$(find . -path "./TO_LOAD" -prune -o -iname "*.csv" -type f -print)
for i in $FILES
 do
	ANO=$(echo $i | sed -r "s/.*([0-9]{4}).*/\1/g")
	echo $ANO
	NOME=$(echo $i | sed -r "s/(.*)\/(.*$)/\2/g;s/(\_{0,1}[0-9]{4}\_{0,1})//g;s/.csv|.CSV//g")
	echo $NOME

# Converte para UTF-8
	iconv -f ISO-8859-2 -t UTF-8 $i > TO_LOAD/$NOME"_"$ANO

# Pega a primeira linha dos arquivos para criar a tabela
	COLUNAS=$(head -1 $i)
        echo "CREATE TABLE IF NOT EXISTS censup."$NOME"_"$ANO" (" > estrutura.sql
        echo $COLUNAS | sed -r "s/\|/ varchar,/g" >> estrutura.sql
        echo " varchar);" >> estrutura.sql

# Etapa de carga
	echo "Criando a estrutura ... "
	 psql -h localhost -U $USUARIO -d educacao -f estrutura.sql
	echo "Realizando a carga .."
	 psql -h localhost -U $USUARIO -d educacao -c "\\COPY censup."$NOME"_"$ANO" FROM TO_LOAD/"$NOME"_"$ANO" CSV HEADER DELIMITER '|' "
 done;

