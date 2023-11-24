# ICDE artifacts for Quokka paper

The reproduction depends on a historical version of the [Quokka](https://github.com/marsupialtail/quokka) query engine and some of its branches. For convenience, we have 
included in this repo a zipped folder of this version, which should also include all of its branches. We have included the Jupyter notebook which is used to generate all of the 
figures. We have also included all the raw measurements data in csv files that serve as input to the Jupyter notebook.

All experiments assume access to an AWS account, and TPC-H data stored in Parquet format stored in S3. 

On the main branch of the zipped Quokka repo, you can reproduce all the performance results for Quokka by running apps/tpc-h/tpch.py

1. Unzip the repo, and go to the quokka directory. Run `pip install .` which should install Quokka.
2. To launch a Quokka cluster on AWS, you need to have generated an AWS access key (.pem) already. Assume you have the key as test.pem, stored in /home/ubuntu/test.pem. You also need a valid security group
set up. You can follow the instructions [here](https://marsupialtail.github.io/quokka/cloud/) for setting that up. You can launch a Quokka cluster with the following commands:
```
from pyquokka.utils import *
manager = QuokkaClusterManager("test", "/home/ubuntu/test.pem", "sg-X")
cluster = manager.create_cluster(AWS_SECRET_KEY, AWS_ACCESS_KEY,  {"r6id.xlarge":16}, amis = {"r6id.xlarge": "ami-0530ca8899fac469f"})
cluster.to_json("16-worker.json")
```
3. You need to edit the json produced in the last step. Go to your AWS console and look at all the machines launched. Note the instance id of the first one. The key of that instance id should be 0.
Swap its key with whatever has key 0 in the json. This is a small bug in this version of Quokka.

4. Once you have done this, you should be able to run apps/tpch/tpc-h.py, which contains implementation of all TPC-H queries in Quokka's DataStream API. This is similar to the Spark DF API.
Note three key lines:
~~~
qc = QuokkaContext(cluster,2, 1)
qc.set_config("fault_tolerance", True)
qc.set_config("blocking", False)
~~~
The first line sets up the number of input and executor TaskManagers per machine. (2,1) is a good number of r6id.xlarge. For r6id.2xlarge use (4,2). You can turn fault tolerance on or off using the next line.
The "blocking" config specifies if you want to do stagewise execution.

You should also change the cluster json and key files in the file to your json file and your key file.

5. To get results for S3 based spooling in Quokka, go to the pyquokka directory. Then replace hbq.py with s3_hbq.py. You need to create an S3 bucket for the spool files, and specify that bucket in hbq.py.
You need to reinstall Quokka by running `pip install .`.

7. To get results for static lineage, you need to switch to the static-lineage branch. Once you are in that branch, You need to reinstall Quokka by running `pip install .`
You will be able to specify another config called "static_lineage", which controls
the number of batches a task consumes at a time. In this paper we test 8 and 128 to illustrate that static lineage strategies might have unstable performance across different cluster configurations.

9. To conduct fault recovery experiments, you can kill a worker machine halfway through the query execution. The apps/tpc-h/tpch.py already contains a convenience method for you to do this called `run_and_kill_after`.
Please change the `ray start` command in that function to point to the **private IP** address of your head node. This function will automatically reconnect this worker after killing it.

------------------------------------------------------------------

To reproduce the SparkSQL and Trino results: follow these steps.

**Trino**:
To launch a 16-worker Trino cluster with fault tolerance (use the trino-ft.json file included):
```
aws emr create-cluster --name "learning" --release-label emr-6.9.0 --applications Name=Trino --ec2-attributes KeyName=X
   --instance-type r6id.xlarge --instance-count 17 --use-default-roles --configurations file:///trino-ft.json
```
Now log onto the instance:
```
aws emr ssh --cluster-id X --key-pair-file Y
```
Start `trino-cli` with `trino-cli --schema default --catalog hive`. Then run the trino-init.sql script provided after changing the bucket name. 
This script will create the appropriate tables and compute cardinality information for Trino's CBO. It is important to compute cardinality for best Trino performance!
Now run the queries provided in queries.sql. You should discard the first run because JVM warm-up times.

To launch the cluster without fault tolerance simply do not pass in the configurations json file.

**Spark**:
To launch a 16-worker Spark cluster (Spark has default tolerance, you can't disable it):
```
aws emr create-cluster --name "learning" --release-label emr-6.9.0 --applications Name=Spark --ec2-attributes KeyName=X
  --instance-type r6id.xlarge --instance-count 17 --use-default-roles
```
Now log onto the instance:
```
aws emr ssh --cluster-id X --key-pair-file Y
```
Run `spark-sql`. Now run the spark-init.sql script after changing the bucket name. Again this will compute the cardinality information for Spark.
Now run the queries provided in queries.sql. You should discard the first run because JVM warm-up times.

To compute fault tolerance results for Spark, make sure after you set up the cluster, you manually edit the /etc/spark/conf such that the following lines are added:
```
spark.network.timeout 2s
spark.executor.heartbeatInterval 1000ms
spark.storage.blockManagerHeartbeatTimeoutMs 2500
spark.network.timeoutInterval 2s
spark.shuffle.io.retryWait      1s
spark.shuffle.io.maxRetries     1
spark.executor.instances 0
```

These are extremely important because Spark's default fault recovery does not start until a couple minutes after the failure, which will make fault recovery very slow.
These configurations make SparkSQL start fault recovery after a couple seconds, same as the default behavior in Quokka.

To get fault recovery performance results, you can randomly kill a worker at 50% execution. AWS EMR will handle the rest. AWS EMR should also automatically bring up a new 
worker instance to be reconnected to the cluster. Do not run any further experiments until AWS EMR dashboard exits the PENDING state for adding new workers!
