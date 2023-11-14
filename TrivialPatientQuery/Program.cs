using System;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections.Generic;
using Dicom;
using Dicom.Network;
using DicomClient = Dicom.Network.Client.DicomClient;


namespace TrivialPatientQuery
{
  internal class Program
  {

    static void Main(string[] args)
    {
      // [Parameter(Mandatory = true)]
      public string MyAE { get; set; } = "QR-TOOL";
      
      // [Parameter(Mandatory = true)]
      public string QrServerAE { get; set; } = "HOROS";
      
      // [Parameter(Mandatory = true)]
      public string QrServerHost { get; set; } = "localhost";
      
      // [Parameter(Mandatory = true)]
      public int QrServerPort { get; set; } = 2763;
      
      // [Parameter(Mandatory = true)]
      public string PatientName { get; set; } = "BEETHOVEN^LUDWIG^VAN";
      
      // [Parameter(Mandatory = true)]
      public string PatientBirthDate { get; set; } = "17700101";
      
      // [Parameter(Mandatory = true)]
      public string Modality { get; set; }
      
      // [Parameter(Mandatory = true)]
      public int MonthsBack { get; set; }
      
      Console.ReadLine(); // keep the window open.
    }
  }
}
