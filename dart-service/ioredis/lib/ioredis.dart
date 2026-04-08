/// Production-grade Redis client for Dart. Full port of ioredis.
library;

// Protocol
export 'src/protocol/resp_encoder.dart';
export 'src/protocol/resp_parser.dart' show RespParser;

// Command
export 'src/command/command.dart' show Command, calculateSlot;
export 'src/command/command_flags.dart';

// Errors
export 'src/errors.dart';

// Client
export 'src/client/redis.dart' show Redis, Pipeline, PubSubMessage;
export 'src/client/redis_options.dart';
export 'src/client/redis_status.dart';

// Connectors
export 'src/connectors/connector.dart';
export 'src/connectors/standalone_connector.dart';
export 'src/connectors/sentinel/sentinel_connector.dart';
export 'src/connectors/sentinel/sentinel_iterator.dart';

// Cluster
export 'src/cluster/cluster.dart';
export 'src/cluster/cluster_options.dart';
export 'src/cluster/connection_pool.dart' show ConnectionPool, NodeRole;

// Scripting
export 'src/scripting/script.dart';
export 'src/scripting/scan_stream.dart';

// Pub/Sub
export 'src/pubsub/subscription_set.dart';

// Typed commands
export 'src/commands/redis_commands.dart';
export 'src/commands/pipeline_commands.dart';

