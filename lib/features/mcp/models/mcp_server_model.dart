/// Statut de disponibilité d'un serveur distant MCP.
enum McpServerStatus { active, connecting, inactive, error }

/// Modèle d'un serveur MCP distant (Model Context Protocol), phase 2
/// du cahier des charges. Les appels réels transitent toujours par
/// l'Edge Function `mcp-proxy`, jamais directement depuis le mobile.
class McpServerModel {
  final String id;
  final String name;
  final String hostUrl;
  final String description;
  final List<String> availableTools;
  final int latencyMs;
  final bool isReadOnly;
  bool isEnabled;
  McpServerStatus status;

  McpServerModel({
    required this.id,
    required this.name,
    required this.hostUrl,
    required this.description,
    required this.availableTools,
    this.latencyMs = 0,
    this.isReadOnly = true,
    this.isEnabled = true,
    this.status = McpServerStatus.inactive,
  });
}
