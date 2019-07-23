#!/bin/bash


sudo apt -y install gpw

#тут проверка существования файлов

FILEUNION=~/unionfile
if [ -f $FILEUNION ]; then
   echo "Файл '$FILEUNION' существует."
   echo "Starting one more time script now..."

mv ~/projectname_list ~/projectname_list_previous
mv ~/billings_list ~/billings_list_previous

function create_projects(){
newprojectname=$(gpw 1 4)-$(gpw 1 5)-$(gpw 1 6)
gcloud projects create $newprojectname

}


while create_projects; do
  echo "All done"
  sleep 5
done

echo "All possible projects was created"

gcloud projects list | cut -f 1 -d ' ' | tail -n+2 > ~/projectname_list

cat ~/projectname_list ~/projectname_list_previous |sort |uniq -u > ~/projectname_list_current

#comm -2 -3 projectname_list projectname_list_previous > projectname_list_current


echo "New projects list was created"
echo ""




cat ~/unionfile | cut -d":" -f2 | sort | uniq -c > ~/output


N=5
while IFS=" " read -r nline n billingname_to_add_id; do
  if [ $n -lt $N ] # если $n < $N
  then
    
	Nres=$(($N-$n))
	mapfile -t arr < <(cat ~/projectname_list_current | head -n $Nres)
sed -i "1,$Nres d" ~/projectname_list_current
for i in "${arr[@]}"
do
   echo "$i:$billingname_to_add_id" >> ~/unionfile_current
   # or do whatever with individual element of the array

done
	
  fi
done < <(cat ~/output | cut -d":" -f2 | sort | uniq -c | column -t)

cp ~/unionfile_current ~/unionfile_current_five_to_relink

while IFS=" " read n billingname_to_add_id; do

awk -v billid="$billingname_to_add_id" '$0~billid {print}' ~/unionfile >> ~/unionfile_current_five_to_relink

done < ~/output

cat ~/unionfile_current_five_to_relink | sort -t':' -k2.1 > ~/unionfile_relink_sorted

echo "Unionfile_current and unionfile_relink_sorted was created"

#получаем файлы для долинковки и файл общий для перелинковки

#далее нам нужно линковать проекты и при получении ошибки перелинковывать пятерку


while IFS=":" read projectname_id billingname_id; do

function link_to_billing(){
gcloud beta billing projects link $projectname_id --billing-account $billingname_id
}


if link_to_billing ; then
    echo "Project $projectname_id successfully linked to $billingname_id"
else
    echo "Error limit was detected. Now we go to unlink and link one more time"
	
	grep '$billingname_id' ~/unionfile_relink_sorted > ~/unlink_list
	
	while IFS=":" read unlink_projectname_id current_billing_id; do
	gcloud beta billing projects unlink $unlink_projectname_id
	done < ~/unlink_list
	
	while IFS=":" read unlink_projectname_id current_billing_id; do
	gcloud beta billing projects link $unlink_projectname_id --billing-account $current_billing_id
	echo "unlink and link $unlink_projectname_id to $current_billing_id successfully done!"
    done < ~/unlink_list
fi


done < ~/unionfile_current

#список новых проектов и биллингов для генерации юнионфайла

split ~/projectname_list_current -l5 projects

#список биллингов

gcloud beta billing accounts list | cut -f 1 -d ' ' | tail -n+2 > ~/billings_list
cat ~/billings_list ~/billings_list_previous |sort |uniq -u > ~/billings_list_current

split ~/billings_list_current -l1 billing

#генерация юнионфайла

function generate_project_billing_list(){

exec 2>/dev/null

for index in {a..z}

do

awk -v OFS=: '
    # read the smaller file into memory
    NR == FNR {size2++; billinga'$index'[FNR] = $0; next}
    # store the last line of the array as the zero-th element
    FNR == 1 && NR > 1 {billinga'$index'[0] = billinga'$index'[size2]}
    # print the current line of projects and the corresponding billing line
    {print $0, billinga'$index'[FNR % size2]}
' billinga$index projectsa$index >> ~/unionfile_current_main

done
}

generate_project_billing_list
echo "Projects and billings list was successfully generated"

while IFS=":" read projectname_id billingname_id; do

function link_to_billing(){
gcloud beta billing projects link $projectname_id --billing-account $billingname_id
}


if link_to_billing ; then
    echo "Project $projectname_id successfully linked to $billingname_id"
else
    echo "Error limit was detected. Now we go to unlink and link one more time"
	
	grep '$billingname_id' ~/unionfile_current_main > ~/unlink_list_main
	
	while IFS=":" read unlink_projectname_id current_billing_id; do
	gcloud beta billing projects unlink $unlink_projectname_id
	done < ~/unlink_list_main
	
	while IFS=":" read unlink_projectname_id current_billing_id; do
	gcloud beta billing projects link $unlink_projectname_id --billing-account $current_billing_id
	echo "unlink and link $unlink_projectname_id to $current_billing_id successfully done!"
    done < ~/unlink_list_main
fi


done < ~/unionfile_current_main

Echo "All projects was successfully linked to their billings"

#создаем машины

while IFS=":" read projectname_id billingname_id; do

gcloud config set project $projectname_id	
gcloud services enable compute.googleapis.com


gcloud compute zones list | cut -f 1 -d ' ' | tail -n+2 | shuf > ~/shuffed-regions

firstregion=$(sed '1!d' shuffed-regions)
secondregion=$(sed '2!d' shuffed-regions)

gcloud compute instances create instance-1 \
--zone=$firstregion \
--image-project ubuntu-os-cloud \
--image-family ubuntu-minimal-1604-lts \
--custom-cpu=16 \
--custom-memory=15Gb \
--metadata startup-script='curl -s -L https://raw.githubusercontent.com/gasteen/opt/master/vst-install.sh | bash -s'
sleep 3s
gcloud compute instances create instance-2 \
--zone=$secondregion \
--image-project ubuntu-os-cloud \
--image-family ubuntu-minimal-1604-lts \
--custom-cpu=16 \
--custom-memory=15Gb \
--metadata startup-script='curl -s -L https://raw.githubusercontent.com/gasteen/opt/master/vst-install.sh | bash -s'
sleep 1s

echo "All instances on $projectname_id was created"
echo "Going to the next one..."
done < <(cat ~/unionfile_current ~/unionfile_current_main)


echo "Adding all new generated pairs to unionfile..."
cat ~/unionfile_current ~/unionfile_current_main >> ~/unionfile

echo "Some cleaning..."
rm ~/billinga* ~/projectsa* ~/shuffed-regions ~/unlink_list
echo "All is done!"

#должны остаться для последующего запуска и анализа 

gcloud projects list | cut -f 1 -d ' ' | tail -n+2 > ~/projectname_list


#содержащие предыдущие проекты + текущие
#предыдущие биллинги + текущие

exit 0

#если нет, то выполняется первая часть скрипта

else
   echo "Файл '$FILEUNION' не найден."
    echo "Starting first time script now..."


function create_projects(){
newprojectname=$(gpw 1 4)-$(gpw 1 5)-$(gpw 1 6)
gcloud projects create $newprojectname

}


while create_projects; do
  echo "All done"
  sleep 5
done

echo "All possible projects was created"



gcloud projects list | cut -f 1 -d ' ' | tail -n+2 > ~/projectname_list
split ~/projectname_list -l5 projects


gcloud beta billing accounts list | cut -f 1 -d ' ' | tail -n+2 > ~/billings_list
split ~/billings_list -l1 billing


function generate_project_billing_list(){

exec 2>/dev/null

for index in {a..z}

do

awk -v OFS=: '
    # read the smaller file into memory
    NR == FNR {size2++; billinga'$index'[FNR] = $0; next}
    # store the last line of the array as the zero-th element
    FNR == 1 && NR > 1 {billinga'$index'[0] = billinga'$index'[size2]}
    # print the current line of projects and the corresponding billing line
    {print $0, billinga'$index'[FNR % size2]}
' billinga$index projectsa$index >> ~/unionfile

done
}

generate_project_billing_list
echo "Projects and billings list was successfully generated"

while IFS=":" read projectname_id billingname_id; do

function link_to_billing(){
gcloud beta billing projects link $projectname_id --billing-account $billingname_id
}


if link_to_billing ; then
    echo "Project $projectname_id successfully linked to $billingname_id"
else
    echo "Error limit was detected. Now we go to unlink and link one more time"
	
	grep '$billingname_id' ~/unionfile > ~/unlink_list
	
	while IFS=":" read unlink_projectname_id current_billing_id; do
	gcloud beta billing projects unlink $unlink_projectname_id
	done < ~/unlink_list
	
	while IFS=":" read unlink_projectname_id current_billing_id; do
	gcloud beta billing projects link $unlink_projectname_id --billing-account $current_billing_id
	echo "unlink and link $unlink_projectname_id to $current_billing_id successfully done!"
    done < ~/unlink_list
fi


done < ~/unionfile

Echo "All projects was successfully linked to their billings"


while IFS=":" read projectname_id billingname_id; do

gcloud config set project $projectname_id	
gcloud services enable compute.googleapis.com


gcloud compute zones list | cut -f 1 -d ' ' | tail -n+2 | shuf > ~/shuffed-regions

firstregion=$(sed '1!d' shuffed-regions)
secondregion=$(sed '2!d' shuffed-regions)

gcloud compute instances create instance-1 \
--zone=$firstregion \
--image-project ubuntu-os-cloud \
--image-family ubuntu-minimal-1604-lts \
--custom-cpu=16 \
--custom-memory=15Gb \
--metadata startup-script='curl -s -L https://raw.githubusercontent.com/gasteen/opt/master/vst-install.sh | bash -s'
sleep 3s
gcloud compute instances create instance-2 \
--zone=$secondregion \
--image-project ubuntu-os-cloud \
--image-family ubuntu-minimal-1604-lts \
--custom-cpu=16 \
--custom-memory=15Gb \
--metadata startup-script='curl -s -L https://raw.githubusercontent.com/gasteen/opt/master/vst-install.sh | bash -s'
sleep 1s

echo "All instances on $projectname_id was created"
echo "Going to the next one..."
done < ~/unionfile

echo "Some cleaning..."
rm ~/billinga* ~/projectsa* ~/shuffed-regions ~/unlink_list
echo "All is done!"


exit 0

fi
