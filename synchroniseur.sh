#!/bin/bash


# Indiquer le chemin absolu des répertoires à synchroniser et du journal de synchronisation
declare repA='/home/alain/Documents/SRT02/LO14/Projet/A/'
declare repB='/home/alain/Documents/SRT02/LO14/Projet/B/'
declare -r journal='/home/alain/Documents/SRT02/LO14/Projet/.synchro/journal'
declare -r journalInter='/home/alain/Documents/SRT02/LO14/Projet/.synchro/journalInter'

function Journaliser {
  eval nomFichier="$1"
  eval message="$2"
  #echo "NomFichier = ${nomFichier}"
  #echo "Message = ${message}"
  #echo "Message = ${message}"
  trouve=1
  (while read ligne
  do
    fichierCourant=$( echo -n $ligne | cut -f1 -d ' ' )
    if [ "$fichierCourant" = "$nomFichier" ]
    then
      let "trouve = 0"
    fi
  done
  #Dans le cas où le fichier est déjà journalisé
    if [ $trouve -eq 0 ]
    then
      perl -pi -e "s/^${nomFichier}.*/$message/g" $journalInter

    else
      #On retire les \ du message
      messageAjuste=$( echo -n $message | sed 's/\\\//\//g' )
      echo $messageAjuste >> $journalInter
    fi
  let "trouve = 1"
  )<$journal
}

function ComparerAuJournal {
  # Vérifie la conformité au journal
  # $1 = Nom du lien ; $2 = Chemin Complet du lien
  numLigne=0
  trouve=1
  (while read ligne
  do
    let "numLigne++"
    fichierCourant=$( echo -n $ligne | cut -f1 -d ' ' )
    #printf "Dans ComparerAuJournal, dollarUn = $1 et fichierCourant = $fichierCourant\n"
    if [ $fichierCourant = $1 ]
    then
      #printf "Les deux fichiers SONT ÉGAUX"
      #printf "ON A TROUVÉ DANS ComparerAuJournal !\n"
      #On a trouvé !
      let "trouve=0"
      #On sélectionne la ligne concernée et on collecte les données utiles
      entree=$( head -n $numLigne $journal | tail -1 )
      permEntree=$( echo -n $entree | cut -f17 -d ' ' )
      tailleEntree=$( echo -n $entree | cut -f21 -d ' ' )
      dateEntree=$( echo -n $entree | cut -f25 -d ' ' )
      checksumEntree=$( echo -n $entree | cut -f30 -d ' ' )
      #On détermine les propriétés du lien donné en paramètres
      valPerm=$( stat -c "%a %n" $2 | cut -f1 -d ' ' )
      valTaille=$( du -k "$2" | cut -f1 -d '	' )
      valDate=$( stat -c %Y "$2" )
      valChecksum=$( sha1sum $2 | cut -f1 -d ' ' )
      #On vérifie si le lien est conforme au journal
      #S'il est conforme, on renvoie 0 ; sinon, on renvoie 1
      if [ $permEntree -eq $valPerm -a $tailleEntree -eq $valTaille -a $dateEntree -eq $valDate -a $checksumEntree =$valChecksum ]
      then
        echo 0
      else
        echo 1
      fi
    fi
  done
  #Si on n'a pas trouvé, on renvoie 1
  if [ $trouve -eq 1 ]
  then
    echo 1
  fi)<$journal
}

function VerifierChecksum {
  # $1 = Chemin vers fichier chez A ; $2 = Chemin vers fichier chez B
  #echo "Je vérifie le checksum"
  checksumA=$( sha1sum $1 | cut -f1 -d ' ' )
  checksumB=$( sha1sum $2 | cut -f1 -d ' ' )
  #echo "CHECKSUMA ET CHECKSUMB => $checksumA ET $checksumB"
  if [ $checksumA = $checksumB ]
  then
    echo 0
  else
    echo 1
  fi
}

function VerifierDate {
  dateA=$( stat -c %Y "$1" )
  dateB=$( stat -c %Y "$2" )
  if [ $dateA -eq $dateB ]
  then
    echo 0
  else
    echo 1
  fi
}

function VerifierTaille {
  tailleLienA=$( du -k "$1" | cut -f1 -d '	' )
  tailleLienB=$( du -k "$2" | cut -f1 -d '	' )
  if [ $tailleLienA -eq $tailleLienB ]
  then
    echo 0
  else
    echo 1
  fi
}

function VerifierPermission {
  #echo "PERMISSION PERMISSION PERMISSION PERMISSION PERMISSION"
  ## Ici, stat pose problème
  permA=$( stat -c "%a %n" $1 | cut -f1 -d ' ' )
  permB=$( stat -c "%a %n" $2 | cut -f1 -d ' ' )
  #echo "PermA = $permA"
  #echo "PermB = $permB"
  if [ $permA = $permB ]
  then
    echo 0
  else
    echo 1
  fi
}

function VerifierPresenceEtCorriger {
  #$1 et $2 => Les deux répertoires étudiés
  #On vérifie la présence sur A à partir un lien sur B
  for lienA in $( ls $1 )
  do
    trouveA=1
    for lienB in $( ls $2 )
    do
      if [ $lienA = $lienB ]
      then
        # Si le fichier a été trouvé chez B
        let "trouveA = 0"
      fi
    done
    if [ $trouveA -eq 1 ]
    then
      #printf "$lienA -> n'a PAS de semblable\n"
      CHOIX=`zenity --list --title=Lien\ orphelin --text=$lienA\ existe\ sur\ A\ mais\ pas\ sur\ B --column=Votre\ Décision Conserver\ le\ lien,\ le\ copier\ sur\ l\'autre\ arborescence\ et\ journaliser Supprimer\ le\ lien\ et\ le\ retirer\ du\ journal\ si\ besoin` && \
      case "${CHOIX}" in
        "") echo "Vous n'avez rien choisi";;
        "Conserver le lien, le copier sur l'autre arborescence et journaliser") echo "Vous avez choisi de conserver le lien";
        cp -R -p $1$lienA $2;

        for rep in $( find $repA -name $lienA )
        do
          valPerm=$( stat -c "%a %n" $rep | cut -f1 -d ' ' );
          valTaille=$( du -k "$rep" | cut -f1 -d '	' );
          valDate=$( stat -c %Y "$rep" );
          dateEcrite=$( stat -c %y "$rep" | cut -f1 -d ' ');
          valChecksum=$( sha1sum $rep | cut -f1 -d ' ' );
          # cheminA=$( echo -n $1 | sed 's/\//\\\//g' );
          # cheminB=$( echo -n $2 | sed 's/\//\\\//g' );
          repRel=$( echo $rep | cut -f8-999 -d '/' | sed 's/\//\\\//g' )
          cheminA=$( echo $repA$repRel | sed 's/\//\\\//g' )
          cheminB=$( echo $repB$repRel | sed 's/\//\\\//g' )
          #echo $rep; echo $repRel; echo $cheminA; echo $cheminB;
          message="$repRel : Chemin chez A : "$cheminA" | Chemin chez B : "$cheminB" | Mode : $valPerm | Taille : $valTaille | Date : $dateEcrite | Checksum = $valChecksum ||| FIN";
          Journaliser "\${lienA}" "\${message}"
        done
        ;;
        "Supprimer le lien et le retirer du journal si besoin") echo "Vous avez choisi de supprimer le lien";
        rm -rf $1$lienA; #Puis on supprime l'entrée du journal si elle y est
        (while read ligne
        do
          fichierCourant=$( echo -n $ligne | cut -f1 -d ' ' )
          echo "SUPPRESSION : "; echo $fichierCourant; echo $2$lienB
          if [ $fichierCourant = $2$lienB -o $fichierCourant = $1$lienB ]
          then
            perl -pi -e "s/^${A}${lienB}.*//g" $journal
            perl -pi -e "s/^${B}${lienB}.*//g" $journal
            sed -i '/^$/d' $journal
          fi
        done)<$journal;;
      esac
    fi
  done

  #On vérifie la présence sur A à partir un lien sur B
  for lienB in $( ls $2 )
  do
    trouveB=1
    for lienA in $( ls $1 )
    do
      if [ $lienB = $lienA ]
      then
        let "trouveB = 0"
      fi
    done
    if [ $trouveB -eq 1 ]
    then
      CHOIX=`zenity --list --title=Lien\ orphelin --text=$lienB\ existe\ sur\ B\ mais\ pas\ sur\ A --column=Votre\ Décision Conserver\ le\ lien,\ le\ copier\ sur\ l\'autre\ arborescence\ et\ journaliser Supprimer\ le\ lien\ et\ le\ retirer\ du\ journal\ si\ besoin` && \
      case "${CHOIX}" in
        "") echo "Vous n'avez rien choisi";;
        "Conserver le lien, le copier sur l'autre arborescence et journaliser") echo "Vous avez choisi de conserver le lien";
        cp -R -p $2$lienB $1;
        for rep in $( find $repB -name $lienB )
        do
          valPerm=$( stat -c "%a %n" $rep | cut -f1 -d ' ' );
          valTaille=$( du -k "$rep" | cut -f1 -d '	' );
          valDate=$( stat -c %Y "$rep" );
          dateEcrite=$( stat -c %y "$rep" | cut -f1 -d ' ');
          valChecksum=$( sha1sum $rep | cut -f1 -d ' ' );
          # cheminA=$( echo -n $1 | sed 's/\//\\\//g' );
          # cheminB=$( echo -n $2 | sed 's/\//\\\//g' );
          repRel=$( echo $rep | cut -f8-999 -d '/' | sed 's/\//\\\//g' )
          cheminA=$( echo $repA$repRel | sed 's/\//\\\//g' )
          cheminB=$( echo $repB$repRel | sed 's/\//\\\//g' )
          #echo $rep; echo $repRel; echo $cheminA; echo $cheminB;
          #  message="$repRel : Chemin chez A : "$cheminA" | Chemin chez B : "$cheminB" | Mode : $valPerm | Taille : $valTaille | Date : $dateEcrite | Checksum = $valChecksum ||| FIN";
          #Journaliser "\${lienA}" "\${message}"
        done
        ;;

        "Supprimer le lien et le retirer du journal si besoin") echo "Vous avez choisi de supprimer le lien";
        rm -rf $2$lienB; #Puis on supprime l'entrée du journal si elle y est
        (while read ligne
        do
          fichierCourant=$( echo -n $ligne | cut -f1 -d ' ' )
          echo "SUPPRESSION : "; echo $fichierCourant; echo $2$lienB
          if [ $fichierCourant = $2$lienB ]
          then
            perl -pi -e "s/^${2}${lienB}.*//g" $journal
            sed -i '/^$/d' $journal
          fi
        done)<$journal;;

      esac
    fi
  done
}

function CorrectionJournal {
  (while read ligne
  do

    fichierCourant=$( echo -n $ligne | cut -f1 -d ' ' )
    trouveEntree=$( find . -wholename "./$fichierCourant" | cut -f2 )
    if [ -z "$trouveEntree" ]
    then
      echo "Aucune occurence de $fichierCourant : on supprime l'entrée"

      sed -i -e "/$fichierCourant/d" $journal
      sed -i '/^$/d' $journal
    fi
  done)<$journal
}



function ParcourirDossier {
  VerifierPresenceEtCorriger $1 $2
  #CorrigerJournal $1 $2
  for lienA in $( ls $1 )
    do
      permLienA=$( stat -c "%a %n" $1$lienA | cut -f1 -d ' ' | cut -c1 )
      if [ $permLienA -eq 4 -o $permLienA -eq 6 -o $permLienA -eq 7 ]
      then
    for lienB in $( ls $2 )
    do
      permLienB=$( stat -c "%a %n" $2$lienB | cut -f1 -d ' ' | cut -c1 )
      if [ $permLienB -eq 4 -o $permLienB -eq 6 -o $permLienB -eq 7 ]
      then
      if [ $lienA = $lienB ]
      then
        # Si les deux liens sont des répertoires, on descend récursivement
        if test -d $1$lienA -a -d $2$lienB
        then
          arg1="$1$lienA/"
          arg2="$2$lienB/"
          ParcourirDossier $arg1 $arg2
          # Si les deux liens sont des fichiers, on détermine les paramètres nécessaires
        elif test -f $1$lienA -a -f $2$lienB
        then
          perm=$( VerifierPermission $1$lienA $2$lienB )
          taille=$( VerifierTaille $1$lienA $2$lienB )
          date=$( VerifierDate $1$lienA $2$lienB )
          checksum=$( VerifierChecksum $1$lienA $2$lienB )
          if [ $checksum -eq 1 ]
          then
            echo "Le contenu de $lienA sur les deux arborescences est différent."
            difference=$( diff $1$lienA $2$lienB )
            echo $difference
            notify-send -t 100 "Différence de contenu sur les deux arborescences pour $lienA" "La fonction diff renvoie : \n $difference \n Le fichier le plus ancien sera remplacé par le plus récent"
          fi
          if [ $perm -eq 0 -a $taille -eq 0 -a $date -eq 0 -a $checksum -eq 0 ]
          then
            for rep in $( find $repA -name $lienA)
            do
              repRel=$( echo $rep | cut -f8-999 -d '/' | sed 's/\//\\\//g' )
              valPerm=$( stat -c "%a %n" $rep | cut -f1 -d ' ' );
              valTaille=$( du -k "$rep" | cut -f1 -d '	' );
              valDate=$( stat -c %Y "$rep" );
              dateEcrite=$( stat -c %y "$rep" | cut -f1 -d ' ');
              valChecksum=$( sha1sum $rep | cut -f1 -d ' ' );
              cheminA=$( echo $repA$repRel | sed 's/\//\\\//g' )
              cheminB=$( echo $repB$repRel | sed 's/\//\\\//g' )
              #echo $rep; echo $repRel; echo $cheminA; echo $cheminB;
              message="$repRel : Chemin chez A : "$cheminA" | Chemin chez B : "$cheminB" | Mode : $valPerm | Taille : $valTaille | Date : $dateEcrite | Checksum = $valChecksum ||| FIN";
              Journaliser "\${lienA}" "\${message}"
            done

          else
            echo "On calcule des comparaisons pour $lienA"
            comparaisonA=$( ComparerAuJournal $lienA $1$lienA )
            comparaisonB=$( ComparerAuJournal $lienB $2$lienB )
            echo "comparaisonA = $comparaisonA et comparaisonB = $comparaisonB"
            #Si le lien sur A est conforme au journal et qu'il ne l'est pas sur B
            if [ $comparaisonA -eq 0 -a $comparaisonB -eq 1 ]
            then
              #On copie de le contenu de B vers A en conservant les métadonnées
              rm $1$lienA;
              cp -R -p $2$lienB $1; #Puis on journalise les fichiers synchronisés
              for rep in $( find $repB -name $lienB )
              do
                valPerm=$( stat -c "%a %n" $rep | cut -f1 -d ' ' );
                valTaille=$( du -k "$rep" | cut -f1 -d '	' );
                valDate=$( stat -c %Y "$rep" );
                dateEcrite=$( stat -c %y "$rep" | cut -f1 -d ' ');
                valChecksum=$( sha1sum $rep | cut -f1 -d ' ' );
                repRel=$( echo $rep | cut -f8-999 -d '/' | sed 's/\//\\\//g' )
                # cheminA=$( echo -n $1 | sed 's/\//\\\//g' );
                # cheminB=$( echo -n $2 | sed 's/\//\\\//g' );
                cheminA=$( echo $repA$repRel | sed 's/\//\\\//g' )
                cheminB=$( echo $repB$repRel | sed 's/\//\\\//g' )
                #echo $rep; echo $repRel; echo $cheminA; echo $cheminB;
                message="$repRel : Chemin chez A : "$cheminA" | Chemin chez B : "$cheminB" | Mode : $valPerm | Taille : $valTaille | Date : $dateEcrite | Checksum = $valChecksum ||| FIN";
                Journaliser "\${lienA}" "\${message}"
              done
              zenity --info --text "<span font-family=\"Arial\">$lienA sur A est conforme au journal mais ne l'est pas sur B</span>
              <span font-family=\"Arial\">Le contenu a été copié de B vers A</span>
              <span font-family=\"Arial\">Les fichiers synchronisés ont été journalisés</span>"
              #Sinon, si le lien sur A n'est pas conforme au journal et qu'il l'est sur B
            elif [ $comparaisonA -eq 1 -a $comparaisonB -eq 0 ]
            then
              #On copie de le contenu de A vers B en conservant les métadonnées
              rm $2$lienB;
              cp -R -p $1$lienA $2; #Puis on journalise les fichiers synchronisés
              for rep in $( find $repA -name $lienA )
              do
                valPerm=$( stat -c "%a %n" $rep | cut -f1 -d ' ' );
                valTaille=$( du -k "$rep" | cut -f1 -d '	' );
                valDate=$( stat -c %Y "$rep" );
                dateEcrite=$( stat -c %y "$rep" | cut -f1 -d ' ');
                valChecksum=$( sha1sum $rep | cut -f1 -d ' ' );
                # cheminA=$( echo -n $1 | sed 's/\//\\\//g' );
                # cheminB=$( echo -n $2 | sed 's/\//\\\//g' );
                repRel=$( echo $rep | cut -f8-999 -d '/' | sed 's/\//\\\//g' )
                cheminA=$( echo $repA$repRel | sed 's/\//\\\//g' )
                cheminB=$( echo $repB$repRel | sed 's/\//\\\//g' )
                #echo $rep; echo $repRel; echo $cheminA; echo $cheminB;
                message="$repRel : Chemin chez A : "$cheminA" | Chemin chez B : "$cheminB" | Mode : $valPerm | Taille : $valTaille | Date : $dateEcrite | Checksum = $valChecksum ||| FIN";
                Journaliser "\${lienA}" "\${message}"
              done
              zenity --info --text "<span font-family=\"Arial\">$lienA sur A n'est pas conforme au journal mais l'est sur B</span>
              <span font-family=\"Arial\">Le contenu a été copié de A vers B</span>
              <span font-family=\"Arial\">Les fichiers synchronisés ont été journalisés</span>"
              #Si aucun n'est conforme au journal (ou s'ils n'y apparaissent pas)
            elif [ $comparaisonA -eq 1 -a $comparaisonB -eq 1 ]
            then
              #On conserve le fichier ayant la date de dernière modification la plus récente
              dateA=$( stat -c %Y "$1$lienA" )
              dateB=$( stat -c %Y "$2$lienB" )
              printf "dateA = $dateA et dateB = $dateB"
              if [ $dateA -ge $dateB ]
              then
                # Si A est plus récent, on conserve A et on supprime B
                printf "dateA est plus récent\n"
                rm $2$lienB;
                cp -R -p $1$lienA $2; # Puis on journalise les fichiers synchronisés
                for rep in $( find repA -name $lienA )
                do
                  valPerm=$( stat -c "%a %n" $rep | cut -f1 -d ' ' );
                  valTaille=$( du -k "$rep" | cut -f1 -d '	' );
                  valDate=$( stat -c %Y "$rep" );
                  dateEcrite=$( stat -c %y "$rep" | cut -f1 -d ' ');
                  valChecksum=$( sha1sum $rep | cut -f1 -d ' ' );
                  # cheminA=$( echo -n $1 | sed 's/\//\\\//g' );
                  # cheminB=$( echo -n $2 | sed 's/\//\\\//g' );
                  repRel=$( echo $rep | cut -f8-999 -d '/' | sed 's/\//\\\//g' )
                  cheminA=$( echo $repA$repRel | sed 's/\//\\\//g' )
                  cheminB=$( echo $repB$repRel | sed 's/\//\\\//g' )
                  #echo $rep; echo $repRel; echo $cheminA; echo $cheminB;
                  message="$repRel : Chemin chez A : "$cheminA" | Chemin chez B : "$cheminB" | Mode : $valPerm | Taille : $valTaille | Date : $dateEcrite | Checksum = $valChecksum ||| FIN";
                  Journaliser "\${lienA}" "\${message}"
                done
                zenity --info --text "<span font-family=\"Arial\">Événement concernant $lienA :</span>
                <span font-family=\"Arial\">Le contenu a été copié de A vers B car sur A le lien a été édité plus récemment</span>
                <span font-family=\"Arial\">Les fichiers synchronisés ont été journalisés</span>"
              else
                # Si B est plus récente, on conserve B et on supprime A
                printf "dateB est plus récent\n"
                rm $1$lienA;
                cp -R -p $2$lienB $1; #Puis on journalise les fichiers synchrinisés
                for rep in $( find $repB -name $lienB )
                do
                  valPerm=$( stat -c "%a %n" $rep | cut -f1 -d ' ' );
                  valTaille=$( du -k "$rep" | cut -f1 -d '	' );
                  valDate=$( stat -c %Y "$rep" );
                  dateEcrite=$( stat -c %y "$rep" | cut -f1 -d ' ');
                  valChecksum=$( sha1sum $rep | cut -f1 -d ' ' );
                  # cheminA=$( echo -n $1 | sed 's/\//\\\//g' );
                  # cheminB=$( echo -n $2 | sed 's/\//\\\//g' );
                  repRel=$( echo $rep | cut -f8-999 -d '/' | sed 's/\//\\\//g' )
                  cheminA=$( echo $repA$repRel | sed 's/\//\\\//g' )
                  cheminB=$( echo $repB$repRel | sed 's/\//\\\//g' )
                  #echo $rep; echo $repRel; echo $cheminA; echo $cheminB;
                  message="$repRel : Chemin chez A : "$cheminA" | Chemin chez B : "$cheminB" | Mode : $valPerm | Taille : $valTaille | Date : $dateEcrite | Checksum = $valChecksum ||| FIN";
                  Journaliser "\${lienA}" "\${message}"
                done
                zenity --info --text "<span font-family=\"Arial\">Événement concernant $lienA :</span>
                <span font-family=\"Arial\">Le contenu a été copié de B vers A car sur B le lien a été édité plus récemment</span>
                <span font-family=\"Arial\">Les fichiers synchronisés ont été journalisés</span>"
              fi
            fi
          fi
          # Les deux cas où l'un est fichier et l'autre est un répertoire (et vice versa)
        elif test -f $1$lienA -a -d $2$lienB
        then
          echo "Conflit pour $1$lienA (fichier) et -$2$lienB (répertoire)"
          CHOIX=`zenity --list --title=Conflit --text=$lienA\ est\ un\ fichier\ sur\ A\ mais\ un\ répertoire\ sur\ B --column=Votre\ Décision Remplacer\ le\ fichier\ par\ le\ répertoire Remplacer\ le\ répertoire\ par\ le\ fichier` && \
          case "${CHOIX}" in
            "") echo "Vous n'avez rien choisi";;
            "Remplacer le fichier par le répertoire") echo "Vous avez choisi de remplacer le fichier par le répertoire";
            rm $1$lienA;
            cp -R -p $2$lienB $1; #Puis on descend récursivement dans les deux RÉPERTOIRES pour finir la journalisation
            arg1="$1$lienB/";
            arg2="$2$lienB/";
            ParcourirDossier $arg1 $arg2;;
            "Remplacer le répertoire par le fichier") echo "Vous avez choisi de remplacer le répertoire par le fichier";
            rm -rf $2$lienB;
            cp -R -p $1$lienA $2; #Puis on journalise les deux fichiers synchronisés
            for rep in $( find $repA -name $lienA )
            do
              valPerm=$( stat -c "%a %n" $rep | cut -f1 -d ' ' );
              valTaille=$( du -k "$rep" | cut -f1 -d '	' );
              valDate=$( stat -c %Y "$rep" );
              dateEcrite=$( stat -c %y "$rep" | cut -f1 -d ' ');
              valChecksum=$( sha1sum $rep | cut -f1 -d ' ' );
              # cheminA=$( echo -n $1 | sed 's/\//\\\//g' );
              # cheminB=$( echo -n $2 | sed 's/\//\\\//g' );
              repRel=$( echo $rep | cut -f8-999 -d '/' | sed 's/\//\\\//g' )
              cheminA=$( echo $repA$repRel | sed 's/\//\\\//g' )
              cheminB=$( echo $repB$repRel | sed 's/\//\\\//g' )
              ##echo $rep; echo $repRel; echo $cheminA; echo $cheminB;
              message="$repRel : Chemin chez A : "$cheminA" | Chemin chez B : "$cheminB" | Mode : $valPerm | Taille : $valTaille | Date : $dateEcrite | Checksum = $valChecksum ||| FIN";
              Journaliser "\${lienA}" "\${message}"
            done
            ;;
          esac
        elif test -d $1$lienA -a -f $2$lienB
        then
          echo "Conflit pour $1$lienA (répertoire) et -$2$lienB (fichier)"
          CHOIX=`zenity --list --title=Conflit --text=$lienA\ est\ un\ répertoire\ sur\ A\ mais\ un\ fichier\ sur\ B --column=Votre\ Décision Remplacer\ le\ fichier\ par\ le\ répertoire Remplacer\ le\ répertoire\ par\ le\ fichier` && \
          case "${CHOIX}" in
            "") echo "Vous n'avez rien choisi";;
            "Remplacer le fichier par le répertoire") echo "Vous avez choisi de remplacer le fichier par le répertoire";
            rm $2$lienB;
            cp -R -p $1$lienA $2; # Puis on descend récursivement dans les deux réperotires pour finir la journalisation
            arg1="$1$lienA/";
            arg2="$2$lienA/";
            ParcourirDossier $arg1 $arg2;;
            "Remplacer le répertoire par le fichier") echo "Vous avez choisi de remplacer le répertoire par le fichier";
            rm -rf $1$lienA;
            cp -R -p $2$lienB $1; # Puis on journalise des deux fichiers synchronisés
            for rep in $( find $repB -name $lienB )
            do
              valPerm=$( stat -c "%a %n" $rep | cut -f1 -d ' ' );
              valTaille=$( du -k "$rep" | cut -f1 -d '	' );
              valDate=$( stat -c %Y "$rep" );
              dateEcrite=$( stat -c %y "$rep" | cut -f1 -d ' ');
              valChecksum=$( sha1sum $rep | cut -f1 -d ' ' );
              # cheminA=$( echo -n $1 | sed 's/\//\\\//g' );
              # cheminB=$( echo -n $2 | sed 's/\//\\\//g' );
              repRel=$( echo $rep | cut -f8-999 -d '/' | sed 's/\//\\\//g' )
              cheminA=$( echo $repA$repRel | sed 's/\//\\\//g' )
              cheminB=$( echo $repB$repRel | sed 's/\//\\\//g' )
              #echo $rep; echo $repRel; echo $cheminA; echo $cheminB;
              message="$repRel : Chemin chez A : "$cheminA" | Chemin chez B : "$cheminB" | Mode : $valPerm | Taille : $valTaille | Date : $dateEcrite | Checksum = $valChecksum ||| FIN";
              Journaliser "\${lienA}" "\${message}"
            done
            ;;
          esac
        fi
      fi
    else
      echo $2$lienB
      echo "Fichier inaccessible en lecture, synchronisation impossible."
    fi
    done
  else
    echo $1$lienA
    echo "FIchier inaccessible en lecture, synchronisation impossible."
  fi
  done
}

CorrectionJournal $repA $repB
ParcourirDossier $repA $repB
rm $journal; touch $journal
awk '!a[$0]++' $journalInter > $journal
perl -pi -e 's/\\\//\//g' $journal
rm $journalInter
CorrectionJournal $repA $repB
