# -*- coding: utf-8 -*-
"""
Created on Fri May 24 15:41:00 2013

@author: proto
"""
import testtools
import unittest
#import libsbml2bngl
from evaluate import evaluate,validate
from os import listdir,devnull
from os.path import isfile, join,getsize
import copasi
from subprocess import call        

##Taken from: http://eli.thegreenplace.net/2011/08/02/python-unit-testing-parametrized-test-cases/

class ParametrizedTestCase(unittest.TestCase):
    """ TestCase classes that want to be parametrized should
        inherit from this class.
    """
    def __init__(self, methodName='runTest', param=None):
        super(ParametrizedTestCase, self).__init__(methodName)
        self.param = param

    @staticmethod
    def parametrize(testcase_klass, param=None):
        """ Create a suite containing all tests taken from the given
            subclass, passing them the parameter 'param'.
        """
        testloader = unittest.TestLoader()
        testnames = testloader.getTestCaseNames(testcase_klass)
        suite = unittest.TestSuite()
        for name in testnames:
            suite.addTest(testcase_klass(name, param=param))
        return suite
        
class TestOne(ParametrizedTestCase):
    '''
    Test for raw translation
    '''
    '''    
    def test_raw(self):
        print self.param
        self.assertEqual(call(['python','sbmlTranslator.py','-i',
        'XMLExamples/curated/BIOMD%010i.xml' % self.param,
        '-o','raw/output' + str(self.param) + '.bngl',
        '-c','reactionDefinitions/reactionDefinition7.json',
        '-n','config/namingConventions.json']),0)        
    '''

    '''
    Test for ability to ruleify
    '''
    def test_parsing(self):
        print self.param
        #reactionDefinitions, useID = libsbml2bngl.selectReactionDefinitions('BIOMD%010i.xml' % self.param)
        #spEquivalence = detectCustomDefinitions(bioNumber)
        self.longMessage = True
        #self.longMessage = True
        result = -1
        try:
            with open(devnull,"w") as f:
                result = call(['python','sbmlTranslator.py','-i',
                #'XMLExamples/curated/BIOMD%010i.xml' % self.param,
                self.param,
                '-o','non_complex/' + str(self.param.split('/')[-1]) + '.bngl',
                '-c','config/reactionDefinitions.json',
                '-n','config/namingConventions.json',
                '-a'],stdout=f)
        except Exception as e:
            print '---',self.param
        finally:        
            if result != 0:
                print result,self.param
            self.assertEqual(result,0,self.param +'\n')

class TestValid(ParametrizedTestCase):
    '''
    Test for whether a file is recognized as correct by bng --check
    '''
    def test_valid(self):
        fileName = self.param
        print fileName
        self.assertEqual(validate(fileName),0)

class TestEval(ParametrizedTestCase):
    """
    Test for whether a file is able to be simulated by bionetgen
    """
    def test_eval(self):
        fileName = self.param
        print fileName
        self.assertEqual(evaluate(fileName),0)

class TestCopasi(ParametrizedTestCase):
    """
    Test for whether the time series generated by a translated version matches that of
    the original one
    """
    def test_copasi(self):
        fileNumber = self.param
        score = copasi.evaluate(fileNumber)
        self.assertAlmostEqual(score, 0, delta=1e-2)
    
def getValidBNGLFiles(directory):
    """
    Gets a list of bngl files that could be correctly translated in a given 'directory'
    """
    onlyfiles = [ f for f in listdir('./' + directory) if isfile(join('./' + directory, f)) ]
    
    logFiles = [x[0:-4] for x in onlyfiles if 'log' in x]
    errorFiles = []
    #dont skip the files that only have warnings    
    for log in logFiles:    
        with open('./' + directory + '/' + log +'.log','r') as f:
            k = f.readlines()
            if 'ERROR' in ','.join(k):
                errorFiles.append(log)
    bnglFiles = [x for x in onlyfiles if 'bngl' in x and 'log' not in x and 'dict' not in x]
    
    validFiles = [x for x in bnglFiles if x not in errorFiles]
    import re
    validNumbers = []
    for x in validFiles:
        number = re.search('output([0-9]+)',x)    
        if number != None:
            validNumbers.append(number.group(1))
        
    return validNumbers

import fnmatch
def getValidXMLFiles(directory):
    """
    Gets a list of bngl files that could be correctly translated in a given 'directory'
    """
    matches = []
    for root, dirnames, filenames in os.walk(directory):
        for filename in fnmatch.filter(filenames, '*.xml'):
            matches.append(os.path.join(root, filename))
    return matches

def getValidGDats(directory):
    onlyfiles = [ f for f in listdir('./' + directory) if isfile(join('./' + directory, f)) ]
    gdatFiles = [x for x in onlyfiles if 'gdat' in x]
    validNumbers = []
    import re
    for x in gdatFiles:
        number = re.search('output([0-9]+)',x)    
        if number != None:
            validNumbers.append(number.group(1))
        
    return validNumbers



class TracingStreamResult(testtools.StreamResult):
    def status(self, *args, **kwargs):
        print('{0[test_id]}: {0[test_status]}'.format(kwargs))
    
def split_suite_into_chunks(num_threads, suite):
    # Compute num_threads such that the number of threads does not exceed the value passed to the function
    # Keep num_threads to a reasonable number of threads
    if num_threads < 0: num_threads = 1
    if num_threads > 8: num_threads = 8
    num_tests = suite.countTestCases()
    s = []
    s_tmp = unittest.TestSuite()
    n = round(num_tests / num_threads)
    for case in suite:
        if n <= 0 and s_tmp.countTestCases() > 0:
            s.append([s_tmp, None])
            num_threads -= 1
            num_tests -= s_tmp.countTestCases()
            s_tmp = unittest.TestSuite()
            n = round(num_tests / num_threads)
        s_tmp.addTest(case)
        n -= 1
    if s_tmp.countTestCases() > 0:
        if s_tmp.countTestCases() > 0: s.append([s_tmp, None])
        num_tests -= s_tmp.countTestCases()
    if num_tests != 0: print("Error: num_tests should be 0 but is %s!" % num_tests)
    return s
    
if __name__ == "__main__":      
    suite = unittest.TestSuite()
    #suite2 = unittest.TestSuite()
    #suite3 = unittest.TestSuite()
    
    #ran = [151]
    ran = range(1,549)
    #ran  = [252]
    #ran = [452,453,465,474,492,500,501,504,505,506,510]
    blackList = []
    ran = [x for x in ran if x not in blackList]
    #check 32
    #ran = range(466,470)
    #ran = [229]
    #ran = range(469,491)
    '''
    ran = [244, 19, 183, 144, 268, 450, 152, 406, 446, 265, 235, 88, 175, 412,
           147, 338, 297, 293, 49, 344, 83, 230, 453, 223, 109, 56, 256, 410, 
           340, 452, 286, 399, 445, 285, 457, 74, 250, 334, 227, 205, 339, 151, 
           424, 14, 153, 105, 407, 451, 332, 326, 255, 356]
    ''' 
    #ran  = [5,6,7,36,56,107,111,144,195,265,297,306,307,308,309,310,311,312]       
    #ran  = [19]  
    files = getValidXMLFiles('XMLExamples/non_curated/')
    files = sorted(files,key=os.path.getsize)
    #files = getValidXMLFiles('biomodels')
    #print files
    for index in files:
        suite.addTest(ParametrizedTestCase.parametrize(TestOne, param=index))
    #for fileName in validFiles:
    suite4 = testtools.ConcurrentStreamTestSuite(lambda: (split_suite_into_chunks(32,suite)))
    validFiles = getValidBNGLFiles('raw') 
    validFiles = sorted(validFiles)
    #validFiles.remove('54')
    
    #validFile= [480]
    '''
    for fileNumber in validFiles:
        #index += 1
        fileName = 'output{0}.bngl'.format(fileNumber)
        #suite.addTest(ParametrizedTestCase.parametrize(TestValid,param='./raw/' + fileName))
        suite.addTest(ParametrizedTestCase.parametrize(TestEval,param='./complex/' + fileName))
        
    validGdats = getValidGDats('.')
    '''
    #validFiles = getValidBNGLFiles('complex')
    #for fileNumber in validFiles:
    #    fileName = 'output{0}.bngl'.format(fileNumber)
    #    suite.addTest(ParametrizedTestCase.parametrize(TestEval,param='./complex/' + fileName))
    #for index in validGdats:
    #    suite.addTest(ParametrizedTestCase.parametrize(TestCopasi, param=index))
    #unittest.TextTestRunner(verbosity=2).run(suite)
    #f = open('logresults.txt','w')
    result = TracingStreamResult()
    result.startTestRun()
    suite4.run(result)
    result.stopTestRun()    


    #suite4.run(testtools.StreamResult())
    #suite4.run(testtools.StreamSummary())
    #print len(validFiles)

