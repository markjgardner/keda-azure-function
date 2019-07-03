# DIY FaaS with KEDA and Azure Functions Runtime

This repo illustrates how you can use KEDA to deploy your own event triggered Azure Functions to a Kubernetes cluster. This implementation is based on the samples provided [here](https://github.com/kedacore/sample-hello-world-azure-functions)

## Deploy KEDA Infrastructure

To deploy the necessary infrastructure to run this project, ```apply``` the included terraform manifest to your own azure subscription. This will create

- An Azure Container Registry for storing the docker image built from this project
- An Azure Storage Account and Queue that will trigger the function whenever messages are enqueued
- An Azure Kubernetes Service instance with KEDA installed

## Deploy the Function

Build and publish your own docker image to the ACR repo:
  docker build -t <acr repo url>/keda-func
  docker push <acr repo url>/keda-func

Update the deploy.yaml to pull the image from the correct repo:
```yaml
 containers:
      - name: keda-func
        image: <acr repo url>/keda-func
```

Apply the deployment to the cluster:

```sh
kubectl apply -f deploy.yaml
```