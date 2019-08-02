
# based on the latest LTS release (curretnly version 18)
FROM ubuntu:latest

LABEL description="adapted base image from BeakerX and Jupyter-base to install all dependencies outside any conda environment (otherwise plotyly file write does not work i.e. plotly-orca problem) and correct user permissions for propper conda/jupyter usage"

ARG NB_USER="jupyter"
ARG NB_UID="1000"
ARG NB_GID="100"

# package install requires root
USER root

ENV DEBIAN_FRONTEND noninteractive
# install all OS dependencies for notebook server, BeakerX compilation (build requires git) and ploty
RUN apt-get update && apt-get install -y --no-install-recommends \
# dependencies to fetch and install yarn, conda and beakerx
	apt-utils \
	sudo \
	curl \
	unzip \
	bzip2 \
	git \
	wget \
	# older versions (below 1.4.1) of beakerx require additional compile tools like make
	# build-essential \
	software-properties-common apt-transport-https gpg-agent locales \
# other tools
	vim-tiny \
# add additional repo to have all dependencies for plotly available
	&& wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - && \
	echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' | sudo tee /etc/apt/sources.list.d/google-chrome.list \
# install plotly (orca) dependencies	
	&& apt-get update && apt-get install -y --no-install-recommends \
	libgtk2.0-0 libgconf-2-4 xvfb google-chrome-stable \
# install yarn (npm) as required by beakerx and jupyterlab
	&& curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
	apt-get update && apt-get install -y --no-install-recommends yarn \
# cleanup		
	&& apt-get clean

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

# Add a script that we will use to correct permissions after running certain commands
COPY fix-permissions.sh /usr/local/bin/fix-permissions

# Create NB_USER according to ARG NB_user user with UID=1000 and in the 'users' group,
# ensure sudo uses the original (user) path
# and make sure these dirs are writable by the `users` group.
RUN chmod +rx /usr/local/bin/fix-permissions && \
	sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
	echo "\n Defaults !secure_path\n" >> /etc/sudoers && \
  echo "\n${NB_USER} ALL=(ALL) NOPASSWD: ALL\n" >> /etc/sudoers && \
  useradd -m -s /bin/bash -N -u $NB_UID -g ${NB_GID} $NB_USER && \
  mkdir -p $CONDA_DIR && chown $NB_USER:$NB_GID $CONDA_DIR && \
	echo 'export PATH=${CONDA_DIR}/bin:$PATH' > /etc/profile.d/conda.sh && \
  chmod g+w /etc/passwd && \
	fix-permissions $HOME && \
  fix-permissions "$(dirname $CONDA_DIR)"

USER $NB_USER

# Setup work directory

RUN mkdir $HOME/workspace

# install conda 
# install beakerx dependencies and plotly
# have all cleanup tasks in the same RUN command to keep the image layers small if possible
# some dependencies (pandas, jupyterhub, plotly) require root priviledges
RUN  cd /home/$NB_USER && \
	wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
	/bin/bash ~/miniconda.sh -f -b -p $CONDA_DIR && \
	rm ~/miniconda.sh && \
	conda clean --all -f -y && \
  fix-permissions $CONDA_DIR && \
  fix-permissions /home/$NB_USER && \
	conda update conda && \
# dependencies as specified in BeakerX configuration environment (we install in conda root, since plotly-orca doesn't seam to work in conda environments right now)
	sudo conda install -y -c conda-forge \
	pip \
	"python>=3" \
  openjdk=8.0.121 \
  "notebook>=5.7.6" \
	# older builds are not compatible with the newest tornado version
	# "tornado>=4.2.0,<6.0.0"
  "tornado>6" \
  "ipywidgets>=7.0.0" \
  nodejs \
  pandas \
  maven \
  py4j \
  requests \
# beakerx dependencies (for older versions, use an older jupyterlab version since there seams to be some incompatibility/bugs with >=1.0)
	&& sudo conda install -y -c conda-forge jupyterhub "jupyterlab>=1.0.0" pyzmq pytest \
	&& sudo conda clean --all -f -y && \
  npm cache clean --force && \
  rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
  rm -rf /home/$NB_USER/.cache/yarn && \
	sudo chown -R ${NB_USER}:${NB_GID} ${CONDA_DIR}  && \
  fix-permissions /home/$NB_USER

# FIXME docker does not yet support using args $NB_USER for --chown property
# add files for jupyter
COPY --chown=jupyter:users jupyter_notebook_config.py /etc/jupyter/

# add the code-base for beakerx (to have all kernels available) and compile
# per default move the documentation to the workspace directory
RUN sudo mkdir /home/beakerx && sudo chown ${NB_USER}:${NB_GID} /home/beakerx && \
	git clone --single-branch --branch docker-src https://github.com/Hotzkow/beakerx.git /home/beakerx && \
### build BeakerX source code
# FIXME: for some reason this works fine in windows but fails currently under mac
	cd /home/beakerx && \
	./setup.sh && \
	npm cache clean -f && \
	conda clean --all -f -y && \
	mv /home/beakerx/doc ${HOME}/workspace && \
	mv /home/beakerx/StartHere.ipynb ${HOME}/workspace/BeakerX-Doc.ipynb

# expose the notebook display port
EXPOSE 8888

WORKDIR $HOME/workspace

### install plotly
RUN pip install --no-cache-dir plotly && \
	conda install -y -c plotly plotly-orca psutil && \
	conda clean --all -f -y && \
	sudo chown -R ${NB_USER}:${NB_GID} ${CONDA_DIR} && \
# install jupiterlab extension to make plotly plots visible
	jupyter labextension install @jupyterlab/plotly-extension

#######################################################
### configure Jupyterlab and import custom settings ###
#######################################################

# 	add the user settings files for jupyter lab
ADD --chown=jupyter:users jupyterlab_user-settings.tar.gz ${HOME}/.jupyter/lab/user-settings/\@jupyterlab/
# enable some extensions
RUN sudo chown -R $NB_USER:$NB_GID ${HOME}/.jupyter && \
	sudo chmod -R +rw  /home/${NB_USER}/.jupyter && \
	pip install jupyterthemes && jt -T -t chesterish && \
	jupyter labextension install beakerx-jupyterlab && \
	jupyter nbextension enable beakerx --py --sys-prefix && \
	jupyter nbextension enable beakerx_tabledisplay --py --sys-prefix && \
	jupyter nbextension enable beakerx_databrowser --py --sys-prefix && \
	jupyter labextension install @agoose77/jupyterlab-markup && \
	jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
	jupyter labextension install @jupyterlab/google-drive && \
	jupyter labextension install @jupyterlab/toc && \
	jupyter labextension install @krassowski/jupyterlab_go_to_definition && \
	jupyter labextension install jupyterlab-topbar-extension && \
	jupyter labextension install jupyterlab-system-monitor && \
	jupyter labextension install @jupyterlab/celltags

RUN jupyter labextension install jupyterlab-chart-editor

# does not yet support newest jupyterlab version
# RUN jupyter labextension install @risoms/mdl-jupyterlab-theme 


CMD ["/opt/conda/bin/jupyter", "lab"]

# Using Tini has several benefits:
# 	- It protects you from software that accidentally creates zombie processes, which can (over time!) starve your entire system for PIDs (and make it unusable).
#		- It ensures that the default signal handlers work for the software you run in your Docker image. For example, with Tini, SIGTERM properly terminates your process even if you didn't explicitly install a signal handler for it.
#		- It does so completely transparently! Docker images that work without Tini will work with Tini without any changes.
# ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
# RUN chmod +x /tini
#ENTRYPOINT ["/usr/local/bin/tini", "--", "/docker-entrypoint.sh"]

## NOTE: If you are using Docker 1.13 or greater, Tini is included in Docker itself. This includes all versions of Docker CE. 
#		To enable Tini, just pass the --init flag to docker run.
