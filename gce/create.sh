gcloud container clusters create kbtest --num-nodes=5
gcloud container clusters get-credentials kbtest

kubectl create -f killbill.yaml
