head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 48 | awk '{print "sk_" substr($0,1,8) "_" substr($0,9,8) "_" substr($0,17)}'

# sk_z7JyDp43_c8Sb7K1k_stGsppmd03aIDdNNLFR58IM4xY

# sk_z7JyDp43_c8Sb7K1k_stGsppmd03aIDdNNLFR58IM4xY

