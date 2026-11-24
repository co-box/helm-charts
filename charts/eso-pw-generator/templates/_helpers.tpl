{{- define "eso-pw-generator.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "eso-pw-generator.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- /*
Generator names only have to be unique inside the namespace. Secret and key names are user
controlled, so normalise them to a DNS-1123 subdomain (lowercase, no underscores/dots).
*/ -}}
{{- define "eso-pw-generator.generatorName" -}}
{{- $name := printf "%s-%s-%s" (include "eso-pw-generator.fullname" .root) .secret.name .key.name -}}
{{- $name | lower | replace "_" "-" | replace "." "-" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
