cat <<EOF > ${kubeconfig}
apiVersion: v1
kind: Config
clusters:
- name: ${cluster_name}
  cluster:
    certificate-authority-data: ${ca_data}
    server: ${endpoint}
users:
- name: ${cluster_name}
  user:
    token: ${token}
contexts:
- name: ${cluster_name}
  context:
    cluster: ${cluster_name}
    user: ${cluster_name}
    namespace: ${namespace}
current-context: ${cluster_name}
EOF

MANIFEST="$(cat <<EOF
${manifest}
EOF
)"

%{ for r in replace ~}
echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig} apply -f - || echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig} replace --force -f -
%{ endfor ~}

%{ for a in apply ~}
echo "$MANIFEST" | kubectl --kubeconfig=${kubeconfig} apply -f -
%{ endfor ~}


rm ${kubeconfig}
