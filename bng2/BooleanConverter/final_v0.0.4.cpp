#include"BoolExprParser.h"
#include<assert.h>
#include<stdlib.h>
#include<cstdio>

#ifdef HAVE_GETOPT_LONG
#include<unistd.h>
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include<getopt.h>
#endif

#include<iostream>
#include<fstream>
#include<sstream>
#include<string>

using namespace std;
using namespace boolstuff;

ifstream infile;
ofstream outfile;
vector<string> var;
vector<int> state;
vector<string> strRules;
vector<string> strRulesFinal;
vector<string> strSpecies;
vector<string> strMethod;
string strHold;
string strTemp;
int lineCount = 1;
char c;
int numRules = 0;
stringstream streamTemp;
vector<int> ruleLine;

int main(int argc, char* argv[]){
    char* fileName = "test.bngb";
    char* inFileAppend = ".bngb";
    char* outFileAppend = ".bngl";
    char* cstrTemp;
    bool readRules();
    bool readSpecies();
    bool readMethod();
    void writeOut();

    infile.open(fileName);
	if(!infile.is_open()){
		cout << "File not found\n";
		return 1;
	}
	if(strstr(fileName, inFileAppend) != NULL){
	    cstrTemp = new char[strlen(fileName) - strlen(inFileAppend + 1)];
        for(size_t i = 0; i < strlen(fileName) - strlen(inFileAppend + 1); i++)
            cstrTemp[i] = fileName[i];
        strncat(cstrTemp, outFileAppend + 1, strlen(outFileAppend));
	}
    else{
        cstrTemp = new char[strlen(fileName) + strlen(outFileAppend) - 1];
        strcpy(cstrTemp, fileName);
        strcat(cstrTemp, outFileAppend);
    }

    outfile.open(cstrTemp);
	if(!outfile.is_open()){
		cout << "Cannot create outfile\n";
		return 1;
	}

    delete cstrTemp;

    c = infile.get();
    while(true){
    	if(!infile.eof())
    		if(c == '#'){
    			c = infile.get();
    			while(isspace(c)) // skip spaces
                    c = infile.get();
    			while(isalpha(c)){
    				strHold += c;
    				c = infile.get();
    			}
    			if(strHold == "species"){
    			    strHold.resize(0);
    				if(!readSpecies())
                        return 1;
    			}
    			else if(strHold == "rules"){
    			    strHold.resize(0);
    				if(!readRules())
                        return 1;
    			}
    			else if(strHold == "method"){
    			    strHold.resize(0);
    				if(!readMethod())
						return 1;
    			}
    			else{
    			    cout << "Invalid header on line " << lineCount << endl;
    			    return 1;
    			}
    		}
    	else
    		break;
    }

    writeOut();

    cout << fileName << ".bngl created\n";

	infile.close();
	outfile.close();

    return 0;
}



bool readSpecies(){
    while(isspace(c)){ // next read line
        if(c == '\n')
            lineCount++;
        c = infile.get();
    }
    while(c != '#' and !infile.eof()){
        if(isalnum(c) or c == '_'){
            while(isalnum(c) or c == '_'){
                strTemp += c;
                c = infile.get();
            }
            strSpecies.push_back(strTemp);
            state.push_back(1);
            strTemp.resize(0);
        }
        else if(c == '!'){
            c = infile.get();
            while(isalnum(c) or c == '_'){
                strTemp += c;
                c = infile.get();
            }
            strSpecies.push_back(strTemp);
            state.push_back(0);
            strTemp.resize(0);
        }
        else if(!isspace(c)){
            cout << "Invalid character on line " << lineCount << endl;
            return false;
        }
        while(isspace(c)){ // next read line
            if(c == '\n')
                lineCount++;
            c = infile.get();
        }
    }
    return true;
}



bool readRules(){
	bool makeRules();
    BoolExprParser parser;
    while(isspace(c)){ // next read line
        if(c == '\n')
            lineCount++;
        c = infile.get();
    }
    while(true)
        if(isalnum(c) or c == '_'){ // get var before =
            strHold += c;
            c = infile.get();
        }
        else
            break;
    var.push_back(strHold);
    ruleLine.push_back(lineCount);
    strHold.resize(0);
    while(true) // skip ', :, and =; if not there, error
        if(!isalnum(c) and c != '_' and c != '(' and c != '!'){
        	strHold += c;
        	c = infile.get();
        }
        else
        	break;
    if(strHold != "': = "){
    	cout << "Invalid formatting on line " << lineCount << endl;
    	return false;
    }
    strHold.resize(0);
    for(int i = 0; i < 2; i++){ // do 2x, once for yes, once for not
        if(i == 0){
            while(true)
                if(c != '\n'){ // read rest of line after =
                    strHold += c;
                    c = infile.get();
                }
                else
                	break;
        }
        else if(i == 1)
            strHold = "!(" + strHold + ')';
        try{
            BoolExpr<string> *expr = parser.parse(strHold);
            assert(expr != NULL);
            expr = BoolExpr<string>::getDisjunctiveNormalForm(expr);
            if(i == 0)
                streamTemp << expr;
            else
                streamTemp << '*' << expr;
            getline(streamTemp, strTemp);
            strRules.push_back(strTemp);
            streamTemp.str("");
            strTemp.resize(0);
            if(expr == NULL)
                cout << "Line " << lineCount << ": result too large\n";
            delete expr;
        }
        catch(BoolExprParser::Error &err){
            cout << "Line " << lineCount << ": ";
            switch(err.code){
                case BoolExprParser::Error::GARBAGE_AT_END:
                    cout << "garbage at end\n";
                    return false;
                case BoolExprParser::Error::RUNAWAY_PARENTHESIS:
                    cout << "runaway parenthesis\n";
                    return false;
                case BoolExprParser::Error::IDENTIFIER_EXPECTED:
                    cout << "identifier expected\n";
                    return false;
            }
        }
    }
    strHold.resize(0);
    lineCount++;
    if(!makeRules())
        return false;
    strRules.resize(0);
    return true;
}



bool makeRules(){
    size_t k;
    size_t m;
    bool found = false;
    bool reversed;
    int j = -1;
	for(int i = 0; i < int(var.size()); i++){
		c = strRules[i][++j];
		if(c == '*'){
			reversed = true;
			c = strRules[i][++j];
		}
		else
			reversed = false;
		while(true)
			if(c != '\n')
				if(c != '|')
					if(c != '&')
						if(c != '!'){
							while(isalnum(c) or c == '_'){
								strTemp += c;
								c = strRules[i][++j];
							}
                            for(k = 0; k < strSpecies.size(); k++){
                                if(strTemp == strSpecies[k])
                                    for(m = 0; m < strSpecies.size(); m++)
                                        if(var[i] == strSpecies[k]){
                                            found = true;
                                            break;
                                        }
                                if(m != strSpecies.size())
                                    break;
                            }
                            if(!found){
                                cout << "Unrecognized molecule used in rule on line " << ruleLine[k] << endl;
                                return false;
                            }
                            found = false;
							if(strTemp != var[i]){
								strHold += strTemp;
								strHold += "(s~1)";
								strTemp.resize(0);
							}
							else{ // if var[i]
								strHold.resize(0);
								break; // skip rule
							}
						}
						else{ // if !
							c = strRules[i][++j];
							while(isalnum(c) or c == '_'){
								strTemp += c;
								c = strRules[i][++j];
							}
							for(k = 0; k < strSpecies.size(); k++){
                                if(strTemp == strSpecies[k])
                                    for(m = 0; m < strSpecies.size(); m++)
                                        if(var[i] == strSpecies[k]){
                                            found = true;
                                            break;
                                        }
                                if(m != strSpecies.size())
                                    break;
                            }
                            if(!found){
                                cout << "Unrecognized molecule used in rule on line " << ruleLine[k] << endl;
                                return false;
                            }
                            found = false;
							if(strTemp != var[i]){
								strHold += strTemp;
								strHold += "(s~0)";
								strTemp.resize(0);
							}
							else{ // if var[i]
								strHold.resize(0);
								break; // skip rule
							}
						}
					else // if &
						strHold += " + ";
				else{ // if |
					if(!reversed)
						strRulesFinal.push_back(var[i] + "(s~0) + " + strHold + " -> " + var[i] + "(s~1) + " + strHold);
					else // if reversed
						strRulesFinal.push_back(var[i] + "(s~1) + " + strHold + " -> " + var[i] + "(s~0) + " + strHold);
					strHold.resize(0);
					numRules++;
				}
			else // if end of string
				break;
		outfile << "#-------------------------" << endl;
	}
	var.resize(0);
	return true;
}



bool readMethod(){
    while(isspace(c)){ // next read line
        if(c == '\n')
            lineCount++;
        c = infile.get();
    }
	switch(c){ // all are same for now - need to figure out s and h
		case 'a':
			while(true){
				c = infile.get();
				if(isdigit(c))
					strHold += c;
				else if(c == ')')
					break;
			}
			try{
				streamTemp << float(atoi(strHold.c_str()))/numRules*2;
				throw 4;
			}
			catch(int a){ // if numRules == 0
				cout << "Place the method block last\n";
				return false;
			}
			getline(streamTemp, strTemp);
			strMethod.push_back("simulate_ssa({t_end=>" + strTemp + ",n_steps=>" + strHold + "});");
		case 's':
			while(true){
				c = infile.get();
				if(isdigit(c))
					strHold += c;
				else if(c == ')')
					break;
			}
			try{
				streamTemp << float(atoi(strHold.c_str()))/numRules*2;
				throw 4;
			}
			catch(int a){ // if numRules == 0
				cout << "Place the method block last\n";
				return false;
			}
			getline(streamTemp, strTemp);
			strMethod.push_back("simulate_ssa({t_end=>" + strTemp + ",n_steps=>" + strHold + "});");
		case 'h':
			while(true){
				c = infile.get();
				if(isdigit(c))
					strHold += c;
				else if(c == ')')
					break;
			}
			try{
				streamTemp << float(atoi(strHold.c_str()))/numRules*2;
				throw 4;
			}
			catch(int a){ // if numRules == 0
				cout << "Place the method block last\n";
				return false;
			}
			getline(streamTemp, strTemp);
			strMethod.push_back("simulate_ssa({t_end=>" + strTemp + ",n_steps=>" + strHold + "});");
	}
    while(isspace(c)){ // next read line
        if(c == '\n')
            lineCount++;
        c = infile.get();
    }
    strTemp.resize(0);
    streamTemp.str("");
    strHold.resize(0);
    return true;
}




void writeOut(){
	outfile << "begin parameters" << endl
			<< "c 1" << endl
			<< "k 1" << endl
			<< "end parameters" << endl << endl;

	outfile << "begin molecule types" << endl;
	for(size_t i = 0; i < strSpecies.size(); i++)
        outfile << strSpecies[i] << "(s~0~1)" << endl;
	outfile << "end molecule types" << endl << endl;

	outfile << "begin species" << endl;
    for(size_t i = 0; i < strSpecies.size(); i++)
		outfile << strSpecies[i] << "(s~" << state[i] << ") c" << endl;
	outfile << "end species" << endl << endl;

	outfile << "begin observables" << endl;
	for(size_t i = 0; i < strSpecies.size(); i++)
		outfile << "Molecules " << strSpecies[i] << " " << var[i] << "(s~1)" << endl;
	outfile << "end observables" << endl << endl;

	outfile << "begin reaction rules" << endl;
	for(size_t i = 0; i < strRulesFinal.size(); i++)
		outfile << strRulesFinal[i] << " k" << endl;
	outfile << "end reaction rules" << endl << endl;

	outfile << "generate_network({overwrite=>1});" << endl
			<< strMethod[0];

    strRulesFinal.resize(0);
    strSpecies.resize(0);
    strMethod.resize(0);
    var.resize(0);
}
