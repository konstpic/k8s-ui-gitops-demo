{{- define "gitops-dev-apps.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gitops-dev-apps.componentName" -}}
{{- printf "%s-%s" .root.Release.Name .app | lower | trunc 63 | trimPrefix "-" | trimSuffix "-" }}
{{- end }}

{{- define "gitops-dev-apps.labels" -}}
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/part-of: {{ .partOf | quote }}
app.kubernetes.io/instance: {{ .root.Release.Name | quote }}
devapps.kubernetes.io/id: {{ .app | quote }}
env: {{ .env | quote }}
{{- end }}
