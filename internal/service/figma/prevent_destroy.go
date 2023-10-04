package figma

// This is explained in figma/figma/config/terraform/modules/asserts/prevent-destroy/main.tf

import (
	"log"
	"math/rand"
	"strconv"
	"time"

	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func ResourcePreventDestroy() *schema.Resource {
	return &schema.Resource{
		Create: ResourcePreventDestroyCreate,
		Read:   ResourcePreventDestroyRead,
		Delete: ResourcePreventDestroyDelete,
		// Update: Not needed or allowed because there are no callsite
		// controllable parameters
		Importer: &schema.ResourceImporter{
			State: schema.ImportStatePassthrough,
		},

		Timeouts: &schema.ResourceTimeout{
			Create: schema.DefaultTimeout(1 * time.Minute),
			Read:   schema.DefaultTimeout(1 * time.Minute),
			Delete: schema.DefaultTimeout(1 * time.Minute),
		},

		Schema: map[string]*schema.Schema{
			"id": {
				Type:     schema.TypeString,
				Computed: true,
			},
			"triggers": {
				Type:     schema.TypeMap,
				Optional: true,
				ForceNew: true,
			},
		},
	}
}

func ResourcePreventDestroyCreate(d *schema.ResourceData, meta interface{}) error {
	d.SetId(strconv.Itoa(rand.Int()))
	return ResourcePreventDestroyRead(d, meta)
}

func ResourcePreventDestroyRead(d *schema.ResourceData, meta interface{}) error {
	return nil
}

func ResourcePreventDestroyDelete(d *schema.ResourceData, meta interface{}) error {
	log.Printf("Allowing delete. This resource does nothing. Use figma/figma figma_prevent_destroy instead.")
	return nil
}
