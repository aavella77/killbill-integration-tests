KB_SRC_DIR=../../killbill

for i in `kubectl get pods -l app=killbill -o=custom-columns=NAME:.metadata.name --no-headers=true`; do
    kubectl cp killbill.properties $i:/var/lib/killbill/killbill.properties

    kubectl cp $KB_SRC_DIR/profiles/killbill/target/killbill-profiles-killbill-0.20.2-SNAPSHOT.war $i:/var/lib/tomcat/webapps/ROOT.war

    kubectl exec -it $i -- ansible-playbook -i localhost, -e ansible_connection=local -e ansible_python_interpreter=/usr/bin/python -e java_home=/usr/lib/jvm/default-java -vv -e tomcat_owner=tomcat -e tomcat_group=tomcat -e tomcat_home=/var/lib/tomcat -e catalina_home=/usr/share/tomcat -e catalina_base=/var/lib/tomcat /var/lib/tomcat/.ansible/roles/killbill-cloud/ansible/tomcat_restart.yml
done
