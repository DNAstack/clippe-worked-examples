# DNAstack Publisher/Explorer Workflow Examples


## One task Three Ways

This repo demonstrates a very simple task using the `clippe` command line tool, using multiple
different execution engines. 

### Getting Started

```
git clone git@github.com:DNAstack/clippe-worked-examples.git
cd clippe-worked-examples
```

### Wdl

#### MiniWDL

[MiniWDL](https://github.com/chanzuckerberg/miniwdl) started as a set of python bindings for the WDL language. Since its
early days, it has now become a fully fledged execution engine, capable of running workflows at scale through docker-swarm
(and soo kubernetes).

```
pip install miniwdl
miniwdl run examples/wdl/01_search_and_download.wdl
```

#### Cromwell

[Cromwell](https://github.com/broadinstitute/cromwell) is the original execution engine for WDL and can be run in either server or 
command line mode. It supports running 1000's of jobs concurrently and is highly configurable to support a large number of different
execution engines

```
wget https://github.com/broadinstitute/cromwell/releases/download/63/cromwell-63.jar
java -jar cromwell-63.jar run examples/wdl/01_search_and_download.wdl
```

### Cwl

[CWL](https://www.commonwl.org/) is not a software, but a specification (similar to WDL) on how to describe a worklfow. It can be used
to define tasks or 

```
sudo apt-get update
sudo apt-get install cwltool

./examples/cwl/01_search_and_download.cwl
```

### Nextflow

[Nextflow](https://nextflow.io) is a relatively new vertical execution stack for bioinformatics (meaning it defines its own DSL and execution service).
It takes a unique approach by providing a groovy based DSL that is reactive streams based.

```
wget -qO- https://get.nextflow.io | bash
nextflow run --config examples/nextflow/nextflow.config examples/nextflow/01_search_and_download.nf
```
