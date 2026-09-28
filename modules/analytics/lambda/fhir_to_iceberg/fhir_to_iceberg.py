import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ["JOB_NAME", "fhir_export_bucket", "export_prefix"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

fhir_path = f"s3://{args['fhir_export_bucket']}/{args['export_prefix']}"
# Stub: read FHIR NDJSON per resource type and write to Iceberg
df = spark.read.json(fhir_path + "Patient/")
df.write.format("iceberg").mode("append").save("glue_catalog.fhir_registry.patient")
job.commit()
