echo "$KUBECONFIG" > ${kubeconfig_path}
echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig_path} apply -f -
rm ${kubeconfig_path}
