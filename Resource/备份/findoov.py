# -*- coding: utf-8 -*-
# find oov words
# output the corresponding sentence id
from sys import argv

if(len(argv) != 3):
    print """
    The input format should be
    "python findoov.py lexicon.txt text.txt"
    """

scriptname, dir_dict, dir_sentence = argv

# start to generate the lexicon
dictfile = open(dir_dict, 'r')
wordpairs = dictfile.readlines()
lexicon = {}
for wordpair in wordpairs:
    temp = wordpair.split(' ')
    word = temp.pop(0)
    pronounce = temp
    lexicon[word] = pronounce
dictfile.close()
# end

# got sentences and output oovs
sentfile = open(dir_sentence, 'r')
output = open('oovs', 'w')
sentences = sentfile.readlines()
for sentence in sentences:
    oovlist = []
    wordlist = sentence.strip('\n').split(' ')
    for word in wordlist[1:]:
        if word not in lexicon:
            oovlist.append(word)
    if oovlist:
        #oovwords = ''
        output.write(sentence)
        for i in oovlist:
            output.write(str(i) + '\n')
        output.write('\n')
output.close()
sentfile.close()
