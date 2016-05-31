# -*- coding: utf-8 -*-
from sys import argv

scriptname, dir_dict = argv

dictfile = open(dir_dict, 'r')
output = open('charact_dict', 'w')
wordpairs = dictfile.readlines()
for  content in wordpairs:
    wordpair = content.strip('\n')
    word_pron = wordpair.split(' ')
    word = word_pron.pop(0)
    pron = ' '.join(word_pron)
    pron_list = pron.split(' ,')
    word_list = word.split(';')
    assert len(pron_list) == len(word_list)
    for i in range(0, len(pron_list)):
        output.write(word_list[i] + ' ' + pron_list[i] + '\n')
        
    
output.close()
dictfile.close()
