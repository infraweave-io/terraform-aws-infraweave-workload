// CloudWatch Application Signals SLOs for this workload account's services.
//
// Created in the account that owns them rather than centrally. The central
// observability sink shares AWS::ApplicationSignals::ServiceLevelObjective, so
// these appear in the monitoring account's Application Signals view without
// needing a cross-account metric query here.
//
// There is no native AWS provider resource; the type is only reachable through
// Cloud Control. It is FULLY_MUTABLE apart from `Name`.
//
// Both SLIs name CloudWatch metrics directly rather than a discovered service.
// A KeyAttributes SLI is rejected outright when the service has not reported
// yet, and discovery is per account *and* per region — so whether an apply
// succeeded depended on which functions happened to have run recently. See the
// longer note in the central module's slo.tf.

locals {
  // The runner has no AWS/Lambda equivalent to fall back on, so its SLI names the
  // ApplicationSignals metric directly and therefore still needs the environment
  // the runner reports via `deployment.environment`.
  slo_environment_ecs = var.telemetry_environment != "" ? var.telemetry_environment : "ecs:default"

  // Put the deployment in the SLO name too. `Name` is create-only, so a hundred
  // accounts each creating `infraweave-prod-reconciler-availability` would give
  // the monitoring account a hundred identically named rows that cannot be
  // renamed without destroying and recreating every one of them.
  slo_name_suffix = var.telemetry_environment != "" ? var.telemetry_environment : var.environment
}

// Availability only. The reconciler is scheduled drift detection, so how long a
// pass takes is not a user-visible property and a latency objective would
// measure how much infrastructure exists rather than whether the service is
// healthy.
resource "aws_cloudcontrolapi_resource" "reconciler_availability" {
  count = var.enable_service_level_objectives ? 1 : 0

  // Application Signals services are regional, so the SLO has to be created in
  // the same region as the service it names.
  region    = var.region
  type_name = "AWS::ApplicationSignals::ServiceLevelObjective"

  desired_state = jsonencode({
    Name        = "infraweave-${local.slo_name_suffix}-reconciler-availability"
    Description = "Successful reconciler runs in this workload account"

    Sli = {
      SliMetric = {
        MetricDataQueries = [
          {
            Id = "errors"
            MetricStat = {
              Metric = {
                Namespace  = "AWS/Lambda"
                MetricName = "Errors"
                Dimensions = [{
                  Name  = "FunctionName"
                  Value = "infraweave-reconciler-${var.environment}"
                }]
              }
              Period = 60
              Stat   = "Sum"
            }
            ReturnData = false
          },
          {
            Id = "invocations"
            MetricStat = {
              Metric = {
                Namespace  = "AWS/Lambda"
                MetricName = "Invocations"
                Dimensions = [{
                  Name  = "FunctionName"
                  Value = "infraweave-reconciler-${var.environment}"
                }]
              }
              Period = 60
              Stat   = "Sum"
            }
            ReturnData = false
          },
          {
            Id = "availability"
            // Periods with no invocations divide by zero and yield no data,
            // which is what we want — an idle reconciler is neither meeting nor
            // missing its objective.
            Expression = "100*(1-errors/invocations)"
            ReturnData = true
          },
        ]
      }
      MetricThreshold    = var.slo_availability_threshold
      ComparisonOperator = "GreaterThanOrEqualTo"
    }

    Goal = {
      AttainmentGoal   = var.slo_availability_attainment
      WarningThreshold = var.slo_availability_warning
      Interval = {
        RollingInterval = {
          DurationUnit = "DAY"
          Duration     = 28
        }
      }
    }
  })
}

// The runner is a batch ECS task, so this is availability only and deliberately
// has no latency counterpart: a plan legitimately takes twenty seconds or eight
// minutes depending on module size and provider count, so a duration objective
// would measure how much infrastructure a project has rather than whether the
// runner is healthy.
//
// The service exists because the runner opens a `terraform_runner` root span
// with otel.kind = "server", which is what makes Application Signals treat it as
// an entry point rather than an orphaned subsegment of the caller.
//
// Period is 300 rather than 60. Runs are intermittent — a period with no task in
// it has no data rather than a success, and shorter periods make the attainment
// ratio jumpier without saying anything more about the service.
//
// This is the one SLI that still reads the ApplicationSignals namespace. The
// Lambdas fall back to AWS/Lambda Errors and Invocations, which report even when
// a process dies before it can initialize tracing; an ECS task has no equivalent,
// so the runner's only signal is the spans it exports itself. That also means
// this SLI depends on `deployment.environment` being set, unlike the others.
resource "aws_cloudcontrolapi_resource" "runner_availability" {
  count = var.enable_service_level_objectives ? 1 : 0

  region    = var.region
  type_name = "AWS::ApplicationSignals::ServiceLevelObjective"

  desired_state = jsonencode({
    Name        = "infraweave-${local.slo_name_suffix}-terraform-runner-availability"
    Description = "Successful terraform runs in this workload account"

    Sli = {
      SliMetric = {
        MetricDataQueries = [
          {
            Id = "faults"
            MetricStat = {
              Metric = {
                Namespace  = "ApplicationSignals"
                MetricName = "Fault"
                Dimensions = [
                  // The OTel service.name the runner sets for itself, not a
                  // resource name we construct.
                  { Name = "Service", Value = "terraform-runner" },
                  { Name = "Environment", Value = local.slo_environment_ecs },
                ]
              }
              Period = 300
              Stat   = "Sum"
            }
            ReturnData = true
          },
        ]
      }
      // A period is good when it contained no faulted run at all, so this is a
      // count rather than the percentage the KeyAttributes form takes.
      MetricThreshold    = 1
      ComparisonOperator = "LessThan"
    }

    Goal = {
      AttainmentGoal   = var.slo_availability_attainment
      WarningThreshold = var.slo_availability_warning
      Interval = {
        RollingInterval = {
          DurationUnit = "DAY"
          Duration     = 28
        }
      }
    }
  })
}
