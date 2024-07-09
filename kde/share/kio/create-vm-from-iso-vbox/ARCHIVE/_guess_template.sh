filename=$1
echo $filename

distro_based=./CreateVBoxVMfromISO.d/linux-distros-genealogy-export.csv
ifs=';'

# for every first word in line match case insentive to image file name
# on match use second word as template name
# check for existence of found template (just in case we have done wrong in the list)

shopt -s nocasematch
while IFS==$ifs read -r match template; do
    #echo match=$match template=$template
    if [[ "$filename" =~ .*$match.* ]]; then
		echo MATCH: $match
		echo TEMPL: $template
		break;
    fi
done < "$distro_based"
