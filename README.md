# MYOP - Make Your Own Predictor

MYOP is a customizable ab initio gene finding system that facilitates the customization of different strategies.

# Software Requirement

1. [ToPS](https://github.com/ayoshiaki/tops)
2. [SegSeq](https://github.com/ayoshiaki/segseq)
3. [Git](https://git-scm.com/)
4. [Perl - ForkManager](http://search.cpan.org/~dlux/Parallel-ForkManager-0.7.5/ForkManager.pm)
5. [BioPerl](http://www.bioperl.org)
6. Linux or MacOSX

# Installing MYOP

After you have installed the required software, you can install MYOP by following the instructions below:

1. MYOP is available from our GitHub repository.

   ```
   git clone https://github.com/myopdev/myop.git
   ```

2. Copy the `myop` folder to `/usr/local/` folder.

   ```
   sudo cp -r myop /usr/local
   ```

3. Add the following line at the end of the `.profile` file.

   ```
   export PATH=$PATH:/usr/local/myop/scripts
   ```
  
# Predicting genes
You can use the program ``myop-predict.pl`` to predict protein-coding genes.  This program receives the directory ``<model>`` of a trained gene model and a ``<fasta file>``.

```
myop-predict.pl -p <model> -f <fasta file> > out.gtf
```

## Tutorial

1. Download the _C. elegans_ model

   [Pre-trained _C. elegans_ model](https://drive.google.com/uc?export=download&id=0B5edlnlwsocMRHhPM3RHc3ZScmc)

2. Uncompress the tarball

   ```
   tar zxvf celegans.tar.gz
   ```

2. Download the fasta file

   [FASTA file](https://drive.google.com/uc?export=download&id=0B5edlnlwsocMT3lVMzVjNjhqSFU)

3. Execute the ``myop-predict.pl`` program

   ```
   myop-predict.pl -p celegans  -f test.fa > out.gtf
   ```

# Training gene models


You can use the program ``myop-train.pl`` to train a new gene model.  This program receives a ``<fasta file>`` and an associated ``<GTF file>``. This program will download a template that contains a pre-configured model from a Git repository[1].  It returns a directory that will contain the trained gene model.

```
myop-train.pl -g <gtf file> -f <fasta file> -o <output directory>
```

## Tutorial

1. Download the GTF and the Fasta file
  * [GTF file](https://drive.google.com/uc?export=download&id=0B5edlnlwsocMeTRveDVIVlItM2c)
  * [Fasta file](https://drive.google.com/uc?export=download&id=0B5edlnlwsocMdnhGZ3pkMTNUNEk)

2. Execute the ``myop-train.pl``

   ```
    myop-train.pl -g ce6.gtf -f ce6.fa -o celegans
   ```

## Specifying a different model template

To specify a different model template, you can use the option ``-r``

```
myop-train.pl -r <a customized model template> -g <gtf file> -f <fasta file> -o <output directory>
```


[1] The default model template is located at https://github.com/myopdev/myopTemplates.git

# Pre-trained Models 

MYOP provides the following pre-trained gene model, feel free to download it.

## Download all models

* [All pre-trained models]()


## Plants

1. [_A. thaliana_]()
2. [_O. sativa_]()
3. [_Z. mays_]()



## Insect

1. [_D. melanogaster_](https://drive.google.com/uc?export=download&id=0B5edlnlwsocMTG9oaHJDdW1HcUE)


## Mammals

1. [_H. sapiens_]()
2. [_M. musculus_]()
3. [_R. norvegicus_]()

## Parasite

1. [_P. falciparum_]()


## Fish

1. [_D. rerio_]()


## Nematodes

1. [_C. elegans_](https://drive.google.com/uc?export=download&id=0B5edlnlwsocMRHhPM3RHc3ZScmc)

