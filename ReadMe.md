
# Docker Image for Jupyter - BeakerX

This image includes ready to use jupyter kernels for the most common programming languages, i.e. Python, Groovy, Java, Scala, Clojure, SQL, Kotlin.

## Build the image Locally

FIXME: There seams to be a permission issue, preventing Mac OS to successfully build this image (i.e. the beakerx build fails with an permission error). Windows works fine and Linux is untested so far.

```bash
docker build -t jupyter .
```

## Run a container

docker run arguments:<br>

* `-p`: to specify port forwarding for the container, you have to expose the container port `8888` to open any notebooks in your hosts browser; e.g. `-p 8886:8888` allows you to open jupyter in your host browser at url `localhost:8886`
* `-it`: to start the container in interactive mode
* `--rm`: to delete the container as soon as it is stopped

External notebook directories should be mounted to the containers mountpoint `/home/jupyter/workspace/notebooks`.  
For example to mount the directory ./notebooks from the host into the container:
```powershell
-v ${PWD}/notebooks:/home/jupyter/workspace/notebooks
```

#### Example how to start a container:
Precondition: the directory `./notebooks` is configured as *shared* in the docker settings

Windows Powershell:
```powershell
docker run -it --rm -p 8888:8888 -v ${PWD}/notebooks:/home/jupyter/workspace/notebooks jh00/jupyter:latest
```
Mac OS Terminal:
```bash
docker run -it --rm -p 8888:8888 -v "$PWD"/notebooks:/home/jupyter/workspace/notebooks jh00/jupyter:latest
```
(for bash script file it is probably `$(pwd)`)

## Jupyter
If the notebook is already running but you need to get the token later on you can use `jupyter notebook list` to output the link again

we can download and upload files directly to the google cloud within jupyter following [this guide](https://medium.com/@umdfirecoml/a-step-by-step-guide-on-how-to-download-your-google-drive-data-to-your-jupyter-notebook-using-the-52f4ce63c66c)

	* upload the client_id.json file to your Jupyter notebook/lab folder
	* use a Python 3 notebook to execute the GoogleDrive authentification
	* open [https://console.developers.google.com] and add Google Drive API credentials: Google Drive API, Other UI (e.g. Windows, CLI tool), User data
	* create OAuth 2 client_id and download the file
	* then go to OAuth consent screen page and add the scope as required (ie. google drive read only or other priviledges)
	* use the provided python 3 code to authenticate the client -> a file token.json is created on success


## FAQ

* pushing an image to dockerhub
	```
	docker login
	docker tag $localBuildImageName $dockerUsername/$newRepoName:v1.0
	docker push $dockerUsername/$newRepoName:v1.0
	```

* changing vim colors for dark terminal backgrounds: `:set background=dark` 

