#!/bin/bash

### Begin init info
# Autor: Marcelo Santana Camacho <camacho@ufpa.br>
# Data: 22/03/2020
# Afiliação: Campus Universitário de Salinópolis - UFPA
# Descrição: Script para carga dos microdados do Censo da Educação Superior no PostgreSQL. 
### End init info

HOST='localhost'
USUARIO='postgres'
PASSWORD='postgres'
TABLESPACE='public'
BANCO='educacao'
SCHEMA='public'
ANO="$@"
EXTRACT_DIR='./tmp'
FINAL_FILE_DIR='./load'

unzd() {
    local name=`echo ${1#'./'}`
    target=$EXTRACT_DIR"/"${name%'.zip'}
    echo "===> Descompactando para $target"
    unzip -q "$1" -d "${target}"
}

descompacta (){
    local ano=$1
    unzd $MICRODADO
     [[ $? == 0 ]] && echo "===>ZIP descompactado" || echo "Erro ao executar unzip"
     RAR=`find . -iname "*.rar" -type f`
     if [ ! -z ${#RAR} ]; then 
        find . -iname "*.rar" -type f -execdir  unrar x -c- -o+ {} 2&>/dev/null  \;
        [[ $? == 0 ]] && echo "===>RAR descompactado" || echo "Erro ao executar unrar"
     fi
    CSV=`find . -type f -iname "*.csv" -a -ipath "*DADOS*"`
    [[ -z $CSV ]] && retorno=1 || retorno=0
}

criaEstrutura (){
    local COLUNAS=$1
    local TABELA=$2
    local SCHEMA=$3
    local BANCO=$4
    local TABLESPACE=$5
    if [ -z ${#COLUNAS} ];then 
     echo "Erro ao passar as colunas da tabela."
     exit
    fi
     echo "===> Criando a estrutura da tabela $SCHEMA.$TABELA no banco $BANCO..."

    echo "CREATE TABLE IF NOT EXISTS $SCHEMA.$TABELA (" >> estrutura.sql
    echo $COLUNAS | sed -r "s/\|/ varchar,/g" >> estrutura.sql
    echo " varchar) TABLESPACE $TABLESPACE;" >> estrutura.sql
}

for ano in $ANO 
do
    echo "===> Realizando a carga do ano $ano..."
	URL1="http://download.inep.gov.br/microdados/microdados_educacao_superior_$ano.zip"
    URL2="http://download.inep.gov.br/microdados/microdados_censo_superior_$ano.zip"
	MICRODADO=`find . -iname "*$ano.zip" -type f `
    
    if [ -z ${#MICRODADO} ] 
    then    
        echo "===> O arquivo será baixado."
        STATUS=`curl -s -I  $URL1 | head -1 | cut -d' ' -f2`
        [ $STATUS -eq 200 ] && wget $URL1 || echo "Tentando outra URL..." && wget $URL2
        if [ $? -ne 0 ]; then
    echo "Erro ao baixar o arquivo. " 

    echo "Servidor do INEP não disponível"
    exit;
        fi
    fi

    echo " ===> Arquivo existente. Chamando a função para descompactar"
    
    descompacta $ano

    if [ $retorno -eq 0 ] 
    then 
        #CSV=`find . -type f -iname "*.csv" -a -ipath "*DADOS*"`
        CSV=`find . -type f -iname "*.csv" -a -ipath "*DADOS*"`
        echo "$CSV"

    while IFS= read -r arquivos
    do
        echo "===> $arquivos"
        arquivo=`echo $arquivos | sed -e "s/ /_/g"`
        echo "+++ $arquivo"
        NOME=`echo $arquivo | sed -r "s/(.*)\/(.*$)/\2/g;s/(\_{0,1}[0-9]{4}\_{0,1})//g;s/.csv|.CSV//g"`
        #NOME=`echo $arquivo | grep -oi "dm.*.csv$"`
        echo "===> Convertendo o arquivo "$arquivo" para "$FINAL_FILE_DIR"/"$NOME"_"$ano".load"
        iconv -f ISO-8859-2 -t UTF-8 "$arquivos" > $FINAL_FILE_DIR"/"$NOME"_"$ano".load"
        echo "===> Obtendo o cabeçalho do arquivo "$FINAL_FILE_DIR"/"$NOME"_"$ano".load"
        TABLENAME=$NOME"_"$ano
        COLUNAS=`head -1 "$FINAL_FILE_DIR/$TABLENAME.load"`
        echo "Colunas $COLUNAS"
        criaEstrutura $COLUNAS $TABLENAME $SCHEMA $BANCO $TABLESPACE
        PGPASSWORD=$PASSWORD psql -h $HOST -U $USUARIO -d $BANCO -f estrutura.sql
        echo "Realizando a carga .."
        PGPASSWORD=$PASSWORD psql -h $HOST -U $USUARIO -d $BANCO -c "\\COPY $SCHEMA."$NOME"_"$ano" FROM $FINAL_FILE_DIR/"$NOME"_"$ano".load CSV HEADER DELIMITER '|' "
    done <<< "$CSV"
        rm estrutura.sql
        rm -rf load/*
        rm -rf tmp/*
    else
        echo 'Erro na descompactação. Verifique o problema.'
    fi
done;
