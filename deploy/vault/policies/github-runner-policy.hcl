# Permit CRU and list for github path secret/data/github/runner
path "secret/data/github/runner/*" {
	capabilities = [ "create", "read", "update", "list" ]
}
