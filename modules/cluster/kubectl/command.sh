function apply {
  aws eks update-kubeconfig --region ${region} --name ${cluster_name} --kubeconfig ${kubeconfig} "$@"
  kubectl --kubeconfig=${kubeconfig} --namespace=${namespace} apply -f -<<EOF
${manifest}
EOF
}

apply --role-arn ${role_arn} || apply
rm ${kubeconfig}
