# DIY FaaS with KEDA and Azure Functions Runtime

This repo illustrates how you can use KEDA to deploy your own event triggered Azure Functions to a Kubernetes cluster. This implementation is based on the samples provided [here](https://github.com/kedacore/sample-hello-world-azure-functions) but provides a complete zero-to-running example consumable by any DevOps platform team.

## Prerequsites

In order to execute this quickstart, you will need:

  - [Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
  - [terraform](https://www.terraform.io/downloads.html)

## Deploy KEDA Infrastructure

To deploy the necessary infrastructure to run this project, ```apply``` the included terraform manifest to your own azure subscription. This will create

- An Azure Container Registry for storing the docker image built from this project
- An Azure Storage Account and Queue that will trigger the function whenever messages are enqueued
- An Azure Kubernetes Service instance with KEDA installed

## Build the Function


Build and publish your own docker image to the ACR repo:

```sh
  docker build -t <acr repo url>/keda-func
  az acr login -n <acr repo name>
  docker push <acr repo url>/keda-func
```

## Deploy the Function

Update the deploy.yaml to pull the image from the correct repo:

```yaml
 containers:
      - name: keda-func
        image: <acr repo url>/keda-func
```

You will also need to add the storage account connection string as a base64 encoded secret:

```yaml
data:
  AzureWebJobsStorage: <base64 encoded storage account connection string>
```

Get the credentials for the AKS instance:

```sh
az aks get-credentials -g keda-rg -n mykedak8s
```

Apply the deployment to the cluster:

```sh
kubectl apply -f deploy.yaml
```

## Run the Function

Use storage explorer (or a browser, console, whatever) to add some messages to the queue.  You can watch KEDA spin containers up and down as the load increases and decreases. Dropping all the way to zero once the queue is empty and the cooldown window (60 seconds) has elapsed.

```sh
kubectl get pods -w
```