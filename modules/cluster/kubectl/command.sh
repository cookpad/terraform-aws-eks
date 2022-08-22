echo "$KUBECONFIG" > ${kubeconfig_path}

for i in {0..60}
do if kubectl --kubeconfig=${kubeconfig_path} cluster-info &> /dev/null; then
  break
else
  echo "cluster isn't ready yet"
  sleep 5
fi
done

%{ for r in replace ~}
echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig_path} apply -f - || echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig_path} replace --force --save-config -f -
%{ endfor ~}

%{ for a in apply ~}
echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig_path} apply -f -
%{ endfor ~}


rm ${kubeconfig_path}
