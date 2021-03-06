export ADMIN_PASSWORD="unix1234"
export EXTERNAL_SUBNET="192.168.5.0/24"
export EXTERNAL_START="192.168.5.200"
export EXTERNAL_END="192.168.5.254"
export EXTERNAL_GATEWAY="192.168.5.1"
export EXTERNAL_FLOATING="192.168.5.201"
cp /root/keystonerc_admin /root/keystonerc_testk
sed -i "s/OS_USERNAME=admin/OS_USERNAME=testk/" /root/keystonerc_testk
sed -i "s/OS_PASSWORD=.*/OS_PASSWORD=testk/" /root/keystonerc_testk
sed -i "s/OS_TENANT_NAME=admin/OS_TENANT_NAME=testk/" /root/keystonerc_testk
sed -i "s/keystone_admin/keystone_testk/" /root/keystonerc_testk
source /root/keystonerc_admin
openstack project create testk
openstack user create  --project testk --password testk testk
openstack role add --user=testk --project=testk admin
neutron net-create external --router:external
neutron subnet-create --name $EXTERNAL_SUBNET --allocation-pool start=$EXTERNAL_START,end=$EXTERNAL_END --disable-dhcp --gateway $EXTERNAL_GATEWAY external $EXTERNAL_SUBNET
keystone password-update --new-password $ADMIN_PASSWORD
sed -i "s/OS_PASSWORD=.*/OS_PASSWORD=$ADMIN_PASSWORD/" /root/keystonerc_admin
source /root/keystonerc_testk
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
glance image-create --name "cirros" --disk-format qcow2 --container-format bare --file cirros-0.3.4-x86_64-disk.img
tail -1 /root/.ssh/authorized_keys > /root/testk.pub
nova keypair-add --pub-key /root/testk.pub testk
neutron net-create private
neutron subnet-create --name 10.0.0.0/24 --allocation-pool start=10.0.0.2,end=10.0.0.254 --gateway 10.0.0.1 private 10.0.0.0/24
neutron router-create router
neutron router-gateway-set router external
neutron router-interface-add router 10.0.0.0/24
seq 5 | xargs -I -- neutron floatingip-create external
neutron security-group-create testk
neutron security-group-rule-create --direction ingress --protocol tcp --port_range_min 22 --port_range_max 22 --remote-ip-prefix 0.0.0.0/0 testk
neutron security-group-rule-create --protocol icmp --direction ingress  --remote-ip-prefix 0.0.0.0/0 testk
nova boot --flavor m1.tiny --security-groups testk --key-name testk --image cirros --nic net-id=`neutron net-show private -c id -f value` testk
sleep 8
nova floating-ip-associate testk $EXTERNAL_FLOATING
