echo "$KUBECONFIG" > ${kubeconfig_path}

%{ for r in replace ~}
echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig_path} apply -f - || echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig_path} replace --force --save-config -f -
%{ endfor ~}

%{ for a in apply ~}
echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig_path} apply -f -
%{ endfor ~}


rm ${kubeconfig_path}
