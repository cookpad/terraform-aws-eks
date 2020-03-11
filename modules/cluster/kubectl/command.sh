aws eks update-kubeconfig --region ${region} --name ${cluster_name} --kubeconfig ${kubeconfig} --role-arn ${role_arn}
kubectl --kubeconfig=${kubeconfig} --namespace=${namespace} apply -f -<<EOF
${manifest}
EOF
rm ${kubeconfig}
