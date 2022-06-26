# initial image to build upon: #4.0.3-daily
FROM rocker/tidyverse:4.2.1
ENV DEBIAN_FRONTEND=noninteractive

# add lib path
RUN touch ~/.Renviron 
RUN echo "R_LIBS_USER=/usr/lib/R/site-library" >> ~/.Renviron

# install python and pip
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev libxt-dev python3.8 python3-pip python3-setuptools python3-dev  
RUN pip3 install --upgrade pip
ENV PYTHONPATH "${PYTHONPATH}:/app"

# set working directory
WORKDIR /app

# add file for installing packages
ADD requirements.txt .
ADD requirements.R .

# installing python libraries
RUN pip3 install -r requirements.txt

# installing r libraries
RUN Rscript requirements.R

# install magick and system dependencies
RUN sudo apt install r-cran-magick -y